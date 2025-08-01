import os
import shutil
import argparse
import json
import subprocess
import subprocess_conout
import sys
import stat
from tqdm import tqdm

# Permission handler for Windows rm errors
def on_rm_error(func, path, exc_info):
    os.chmod(path, stat.S_IWRITE)
    func(path)

# Load config one level up
topdir = os.path.dirname(__file__)
CONFIG_PATH = os.path.abspath(os.path.join(topdir, '..', 'config.json'))
try:
    with open(CONFIG_PATH) as f:
        config = json.load(f)
except FileNotFoundError:
    print(f"Config not found: {CONFIG_PATH}")
    sys.exit(1)

pbar = None

# Copy with progress

def copy_verbose(src, dst):
    pbar.update(1)
    shutil.copy(src, dst)

def count_files(dirpath, ext=None):
    total = 0
    for _, _, files in os.walk(dirpath):
        if ext:
            files = [f for f in files if f.endswith(ext)]
        total += len(files)
    return total

# Interactive chooser
def choose_target(targets):
    print("Available targets:")
    for i, t in enumerate(targets, 1):
        mark = '*' if t.get('default') else ' '
        print(f" [{i}] {t['name']} {mark}")
    idx = None
    while idx is None:
        try:
            sel = int(input("Select number: "))
            if 1 <= sel <= len(targets):
                idx = sel - 1
            else:
                print("Out of range")
        except ValueError:
            print("Enter a number")
    return [targets[idx]]

# Copy logic

def copy_files(src_override, fileext, targets):
    global pbar
    git_src = src_override or config['git_src']
    tgt = config['tgt_name']
    print(f"Copy mode: {fileext or 'all'}")

    for i, t in enumerate(targets, 1):
        dest = t['dest']; sim = t.get('simulator')
        print(f"[{i}/{len(targets)}] -> {t['name']} @ {dest}")
        out_dir = os.path.join(dest, tgt)

        # .lua only
        if fileext == '.lua':
            if os.path.isdir(out_dir):
                for r, _, files in os.walk(out_dir):
                    for f in files:
                        if f.endswith(('.lua','.luac')):
                            os.remove(os.path.join(r,f))
            scr = os.path.join(git_src, 'scripts', tgt)
            os.makedirs(out_dir, exist_ok=True)
            for r,_,files in os.walk(scr):
                for f in files:
                    if f.endswith('.lua'):
                        shutil.copy(os.path.join(r,f), out_dir)

        # fast
        elif fileext == 'fast':
            scr = os.path.join(git_src, 'scripts', tgt)
            for r,_,files in os.walk(scr):
                for f in files:
                    srcf = os.path.join(r,f)
                    rel = os.path.relpath(srcf, scr)
                    dstf = os.path.join(out_dir, rel)
                    os.makedirs(os.path.dirname(dstf), exist_ok=True)
                    if not os.path.exists(dstf) or os.path.getmtime(srcf)>os.path.getmtime(dstf):
                        shutil.copy(srcf, dstf)
                        print(f"Copy {f}")

        # full
        else:
            if os.path.isdir(out_dir):
                shutil.rmtree(out_dir, onerror=on_rm_error)
            srcall = os.path.join(git_src, 'scripts', tgt)
            total = count_files(srcall)
            pbar = tqdm(total=total)
            shutil.copytree(srcall, out_dir, dirs_exist_ok=True, copy_function=copy_verbose)
            pbar.close()

        print(f"Done: {t['name']}\n")

# Launch sims
def launch_sims(targets):
    for t in targets:
        sim = t.get('simulator')
        if sim:
            print(f"Launching {t['name']}: {sim}")
            out = subprocess_conout.subprocess_conout(sim, nrows=9999, encode=True)
            print(out)

# Main
def main():
    p = argparse.ArgumentParser(description='Deploy & launch')
    p.add_argument('--config', default=CONFIG_PATH)
    p.add_argument('--src')
    p.add_argument('--fileext')
    p.add_argument('--all', action='store_true')
    p.add_argument('--choose', action='store_true')
    p.add_argument('--launch', action='store_true')
    p.add_argument('--radio', action='store_true')
    p.add_argument('--radio-debug', action='store_true')
    args = p.parse_args()

    # load override config
    if args.config != CONFIG_PATH:
        with open(args.config) as f:
            config.update(json.load(f))

    # select targets
    if args.radio:
        rd = subprocess.check_output([config['ethos_bin'],'--scripts-dir'], text=True).strip()
        targets=[{'name':'Radio','dest':rd,'simulator':None}]
    else:
        tlist=config['deploy_targets']
        if args.choose:
            targets=choose_target(tlist)
        elif args.all:
            targets=tlist
        else:
            targets=[t for t in tlist if t.get('default')]

    if not targets:
        print('No targets.')
        sys.exit(1)

    copy_files(args.src, args.fileext, targets)

    if args.launch and not args.radio:
        launch_sims(targets)

    if args.radio and args.radio_debug:
        port=subprocess.check_output([config['ethos_bin'],'--serial','start'],text=True).strip()
        subprocess.run([sys.executable,'-c',
            f"import serial; s=serial.Serial('{port}'); print(s.readline().decode())"]
        )

if __name__=='__main__':
    main()