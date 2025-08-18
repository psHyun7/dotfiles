package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/fsnotify/fsnotify"
)

var (
	homeDir     string
	dotfilesDir string
	dryRun      bool
)

var excludeTops = map[string]struct{}{
	".DS_Store":       {},
	".localized":      {},
	".Trash":          {},
	".git":            {},
	".dotfiles":       {},
	".TemporaryItems": {},
	".fseventsd":      {},
	"Library":         {},
	"Applications":    {},
	"Desktop":         {},
	"Downloads":       {},
}

var tempSuffixes = []string{"~", ".swp", ".swx", ".tmp"}

func isTopLevelDot(p string) (bool, string) {
	rel, err := filepath.Rel(homeDir, p)
	if err != nil {
		return false, ""
	}
	if rel == "." || rel == "" {
		return false, ""
	}
	parts := strings.Split(rel, string(os.PathSeparator))
	if len(parts) == 0 {
		return false, ""
	}
	if strings.HasPrefix(parts[0], ".") {
		return true, parts[0]
	}
	return false, ""
}

func isTempFile(name string) bool {
	for _, s := range tempSuffixes {
		if strings.HasSuffix(name, s) {
			return true
		}
	}
	return strings.HasPrefix(name, ".#")
}

func ensureDir(p string) error {
	return os.MkdirAll(p, 0o755)
}

func backupPath(p string) (string, error) {
	ts := time.Now().Format("20060102-150405")
	b := filepath.Join(dotfilesDir, "backups", ts)
	if err := ensureDir(b); err != nil {
		return "", err
	}
	return filepath.Join(b, filepath.Base(p)), nil
}

func moveFile(src, dst string) error {
	// try rename first
	if err := os.Rename(src, dst); err == nil {
		return nil
	}
	// fallback: copy and remove
	srcf, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcf.Close()
	dstf, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstf.Close()
	if _, err := io.Copy(dstf, srcf); err != nil {
		return err
	}
	if err := os.Remove(src); err != nil {
		return err
	}
	return nil
}

func runStow(pkg string) error {
	// remove .DS_Store inside the target (package or repo root) to avoid stow conflicts
	target := dotfilesDir
	if pkg != "." {
		target = filepath.Join(dotfilesDir, pkg)
	}
	_ = filepath.Walk(target, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info != nil && info.Name() == ".DS_Store" {
			_ = os.Remove(path)
		}
		return nil
	})

	// if pkg is "." we want to stow the repo root (use "." as the package)
	cmd := exec.Command("stow", "-v", "-t", homeDir, pkg)
	cmd.Dir = dotfilesDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func handlePath(p string) {
	ok, top := isTopLevelDot(p)
	if !ok {
		return
	}
	if _, ex := excludeTops[top]; ex {
		log.Printf("excluded top-level: %s", top)
		return
	}
	if top == ".DS_Store" {
		log.Printf("ignoring .DS_Store top-level")
		return
	}
	name := filepath.Base(p)
	if isTempFile(name) {
		log.Printf("ignoring temp file: %s", p)
		return
	}

	topPath := filepath.Join(homeDir, top)
	// if symlink, skip
	fi, err := os.Lstat(topPath)
	if err == nil {
		if fi.Mode()&os.ModeSymlink != 0 {
			log.Printf("already symlink, skipping: %s", topPath)
			return
		}
	}

	// move the file directly into the dotfiles repo root (no per-file package dir)
	destPath := filepath.Join(dotfilesDir, top)

	if _, err := os.Stat(destPath); err == nil {
		// backup existing
		bk, err := backupPath(destPath)
		if err == nil {
			if !dryRun {
				if err := moveFile(destPath, bk); err != nil {
					log.Printf("failed to backup existing %s: %v", destPath, err)
				}
			} else {
				log.Printf("dry-run: would backup %s -> %s", destPath, bk)
			}
		}
	}

	log.Printf("Moving %s -> %s", topPath, destPath)
	if !dryRun {
		if err := moveFile(topPath, destPath); err != nil {
			log.Printf("failed to move: %v", err)
			return
		}
	} else {
		log.Printf("dry-run: would move %s -> %s", topPath, destPath)
	}

	log.Printf("Running stow for repo root (.)")
	if !dryRun {
		if err := runStow("."); err != nil {
			log.Printf("stow failed: %v", err)
		}
	} else {
		log.Printf("dry-run: would run stow .")
	}
}

func importScan() []string {
	moved := []string{}
	entries, err := os.ReadDir(homeDir)
	if err != nil {
		log.Printf("failed to read home dir: %v", err)
		return moved
	}
	for _, e := range entries {
		name := e.Name()
		if !strings.HasPrefix(name, ".") {
			continue
		}
		if _, ex := excludeTops[name]; ex {
			continue
		}
		if e.Type()&os.ModeSymlink != 0 {
			continue
		}
		if name == ".DS_Store" {
			continue
		}
		// import files into the repo root (no per-file package dir)
		destPath := filepath.Join(dotfilesDir, name)
		if _, err := os.Stat(destPath); err == nil {
			log.Printf("package already contains %s, skipping", name)
			continue
		}
		log.Printf("Importing %s -> %s", filepath.Join(homeDir, name), destPath)
		if !dryRun {
			if err := moveFile(filepath.Join(homeDir, name), destPath); err != nil {
				log.Printf("failed to move %s: %v", name, err)
				continue
			}
			if err := runStow("."); err != nil {
				log.Printf("stow failed: %v", err)
			}
		} else {
			log.Printf("dry-run: would import %s", name)
		}
		moved = append(moved, name)
	}
	return moved
}

func watch() error {
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return err
	}
	defer w.Close()

	if err := w.Add(homeDir); err != nil {
		return err
	}

	log.Printf("Watching %s for top-level dotfiles...", homeDir)
	for {
		select {
		case ev, ok := <-w.Events:
			if !ok {
				return nil
			}
			if ev.Op&fsnotify.Create == fsnotify.Create || ev.Op&fsnotify.Rename == fsnotify.Rename {
				handlePath(ev.Name)
			}
		case err, ok := <-w.Errors:
			if !ok {
				return nil
			}
			log.Printf("watcher error: %v", err)
		}
	}
}

func main() {
	home, _ := os.UserHomeDir()
	homeDir = home
	flag.StringVar(&dotfilesDir, "dotfiles-dir", filepath.Join(homeDir, ".dotfiles"), "path to your dotfiles repo")
	scan := flag.Bool("scan", false, "one-shot scan and import existing top-level dotfiles")
	flag.BoolVar(&dryRun, "dry-run", false, "do not move files, just show what would happen")
	verbose := flag.Bool("verbose", false, "verbose logging")
	flag.Parse()
	if *verbose {
		log.SetFlags(log.LstdFlags | log.Lshortfile)
	} else {
		log.SetFlags(log.LstdFlags)
	}
	if dotfilesDir == "" {
		dotfilesDir = filepath.Join(homeDir, ".dotfiles")
	}
	if err := ensureDir(dotfilesDir); err != nil {
		log.Fatalf("failed to create dotfiles dir: %v", err)
	}
	if *scan {
		m := importScan()
		log.Printf("scan complete, moved: %v", m)
		return
	}
	if err := watch(); err != nil {
		fmt.Fprintf(os.Stderr, "watch error: %v\n", err)
		os.Exit(1)
	}
}
