package path_registry

import (
	"path"
	"runtime"
)

// Public facing interface
type IPathRegistry interface {
	Get() ResolvedPathRegistrySpec
	Set(spec UpdatePathRegistrySpec) error
}

// Used for getting the registry
type ResolvedPathRegistrySpec struct {
	ServiceDir       *string
	BinaryInstallDir string
}

// Used for setting part of the registry
type UpdatePathRegistrySpec struct {
	BinaryInstallDir *string
}

// The instance to use (implements platform specific defaults)
var PathRegistry IPathRegistry = &uniform

// Platform specific instances
var (
	windows ResolvedPathRegistrySpec = ResolvedPathRegistrySpec{
		BinaryInstallDir: "C:\\Program Files\\NoPorts",
		ServiceDir:       nil,
	}
	linux_service_dir string                   = "/etc/systemd/system"
	linux             ResolvedPathRegistrySpec = ResolvedPathRegistrySpec{
		BinaryInstallDir: "/usr/local/bin",
		ServiceDir:       &linux_service_dir,
	}
	macos_service_dir string                   = "~/Library/Launch Agents/"
	macos             ResolvedPathRegistrySpec = ResolvedPathRegistrySpec{
		BinaryInstallDir: "/usr/local/bin",
		ServiceDir:       &macos_service_dir,
	}
)

// Interface implementation for platform specific instances
func (spec ResolvedPathRegistrySpec) Get() ResolvedPathRegistrySpec {
	return spec
}

func (spec *ResolvedPathRegistrySpec) Set(change UpdatePathRegistrySpec) error {
	if change.BinaryInstallDir != nil {
		cleaned := path.Clean(*change.BinaryInstallDir)
		spec.BinaryInstallDir = cleaned
		return nil
	}
	return nil
}

// Cache the platform implementation
type UniformPathRegistry struct {
	cached *ResolvedPathRegistrySpec
}

var uniform = UniformPathRegistry{
	cached: nil,
}

// Automatically get and cache based on the runtime os from runtime.GOOS
func (reg *UniformPathRegistry) getAndCache() *ResolvedPathRegistrySpec {
	if reg.cached != nil {
		return reg.cached
	}
	switch runtime.GOOS {
	case "windows":
		reg.cached = &windows
	case "linux":
		reg.cached = &linux
	case "darwin":
		reg.cached = &macos
	}
	return reg.cached
}

// Interface implementation for the uniform caching instance
func (reg UniformPathRegistry) Get() ResolvedPathRegistrySpec {
	return reg.getAndCache().Get()
}

func (reg *UniformPathRegistry) Set(change UpdatePathRegistrySpec) error {
	return reg.getAndCache().Set(change)
}
