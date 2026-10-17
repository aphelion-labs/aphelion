// Command aphelion is the aphelion binary. It reports its version and
// does nothing else yet.
package main

import (
	"flag"
	"fmt"
)

// version is the release version, set at build time with
// -ldflags "-X main.version=<version>" (see the Makefile). Builds without
// that flag report "dev".
var version = "dev"

func main() {
	// --version is accepted so scripts can ask for the version explicitly.
	// The binary has no other behaviour yet, so it prints the version either way.
	flag.Bool("version", false, "print the version and exit")
	flag.Parse()
	fmt.Println("aphelion " + version)
}
