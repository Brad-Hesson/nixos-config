# v6b installation and testing (all code is self-contained below)
#
# Replace the entire previous module with this file, keeping your existing import
# and programs.chromiumDualGpuPrototype.enable = true. Skip v6a. This is a candidate
# implementation, not a confirmed Chromium/Surface Book build. It targets exactly
# Chromium 153.0.8010.47 and vulkan-loader 1.4.357.0; version guards fail early.
#
# Local validation completed:
# - All source replacements applied to the exact upstream Chromium/ANGLE revisions.
# - Generated 761 Vulkan dispatch wrappers compiled against that checkout's headers.
# - Mock test passed 4,000,000 calls on four threads/two devices and 50 key-reuse cycles.
# - Patched Vulkan loader compiled (local test build had WSI disabled).
# - Discovery resolved fixture manifests without executing aborting ICD constructors.
# - Preflight C++ compiled; actual GPU tests require your machine.
# - Nix syntax and embedded test-page JavaScript parsed.
# Nix evaluation, full Chromium compilation, sandboxed driver loading and actual
# Intel/NVIDIA/Onshape/DTX behavior have NOT been validated here.
#
# 1. Build ONLY the inexpensive preflight first. Run from your flake directory;
#    substitute your actual NixOS host and Home Manager user attribute names:
#
#    host=YOUR_HOST
#    hm_user=YOUR_USERNAME
#    attr=".#nixosConfigurations.$host.config.home-manager.users.$hm_user.programs.chromiumDualGpuPrototype"
#    nix build "$attr.preflightPackage" -o result-dualgpu-preflight
#    ./result-dualgpu-preflight/bin/dual-gpu-preflight 2>&1 | tee v6b-preflight.log
#
#    Standalone Home Manager equivalent:
#    attr='.#homeConfigurations.YOUR_CONFIGURATION.config.programs.chromiumDualGpuPrototype'
#
#    Run attached to the base, on AC. Preflight intentionally wakes NVIDIA. Require
#    PASS at the end, both correct vendors, and zero NVIDIA FDs after each teardown.
#    A failure means STOP before compiling Chromium and send the complete log.
#    --metadata-only performs discovery without loading either ICD.
#    Preflight tests this process, not device handles held by unrelated applications.
#    It cannot validate Chromium's sandbox or actual WebGL rendering.
#
# 2. After preflight passes, build Chromium once:
#
#    nix build "$attr.finalPackage" -o result-dualgpu
#
#    You can run this result directly; a full system switch is not required to test.
#    If compilation fails, send the FIRST compiler error and surrounding lines.
#    Do not remove version or exact-match guards to work around an error.
#
# 3. Close other Chromium instances to make FD accounting unambiguous. Start X11
#    first on AC, using a fresh test profile and preserving logs:
#
#    ./result-dualgpu/bin/chromium-dual-gpu-test \
#      --ozone-platform=x11 --user-data-dir="$HOME/.cache/dual-gpu-v6b-x11" \
#      --enable-logging=stderr --v=1 2>&1 | tee v6b-x11.log
#
#    Use a previously unused profile path for the first run. All launcher arguments
#    now reach Chromium. Never reuse a running browser process for a different mode;
#    Chromium may forward to that process and ignore new environment/flags.
#
# 4. In another terminal, run at startup, while high contexts exist, and 10 seconds
#    after removing all high contexts:
#
#    ./result-dualgpu/bin/chromium-dual-gpu-state
#
#    If it reports inaccessible FD entries, rerun the exact helper with sudo:
#    sudo ./result-dualgpu/bin/chromium-dual-gpu-state
#    It respects SUDO_UID. The helper reads proc/sysfs and does not run nvidia-smi.
#    It includes all same-user Chrome/Chromium processes, including sandbox brokers.
#    Zero in this helper is not proof that unrelated applications have no handles.
#
# 5. Acceptance sequence in the test page:
#    a. Only default/low-power frames initially: both Intel; zero NVIDIA device FDs.
#    b. Add two high frames: NVIDIA renderer in both; all four frames animate.
#       GPU process PID stays stable; no context loss, GL/readback errors or SIGSEGV.
#    c. Remove all high frames, keeping Intel frames alive. After cleanup + idle
#       grace, logs show 'terminating idle NVIDIA EGL display' and 'renderer and
#       direct ICD reference released'; NVIDIA FD count returns to zero.
#    d. Run ten cycles. Require the same PID, correct vendors and teardown each time.
#    e. With high frames removed, exercise DTX detach and reattach, then add high
#       frames again. Start the browser attached: discovering hardware first added
#       after a detached startup is not implemented by the retained PCI mapping.
#
#    Idle teardown waits for ALL ANGLE contexts, surfaces, images, syncs and streams.
#    A remaining live-object mask is a failed zero-FD acceptance test, even if the
#    device is suspended. The implementation retains live objects rather than
#    invalidating references. Record the mask; it identifies what blocks teardown.
#
# 6. Onshape: in the same run, open your model, verify NVIDIA renderer, and orbit,
#    pan, zoom, change views and interact for several minutes with Intel test frames
#    still animating. Close the Onshape tab and all high test frames; repeat the
#    10-second FD check. Compare ordinary pages/video scrolling for regressions.
#
# 7. Repeat with --ozone-platform=wayland and a different profile. Only after X11
#    and Wayland pass on AC, repeat on battery. Record AC/battery and DTX state.
#
# Runtime controls (restart browser; these do NOT require recompiling):
#    CHROMIUM_DUAL_GPU_MODE=dual     default: low/default Intel, explicit high NVIDIA
#    CHROMIUM_DUAL_GPU_MODE=intel    all WebGL preferences on Intel
#    CHROMIUM_DUAL_GPU_MODE=nvidia   all preferences on NVIDIA; idle trim disabled
#    CHROMIUM_DUAL_GPU_TRIM=0        keep displays alive to isolate teardown failures
#    CHROMIUM_DUAL_GPU_IDLE_SECONDS=10  choose a grace of 1..60 seconds (default 3)
#    CHROMIUM_DUAL_GPU_ISOLATION=0   diagnostic conventional multi-ICD discovery
#
# Example single-GPU control, after fully exiting the previous prototype:
#    CHROMIUM_DUAL_GPU_MODE=intel ./result-dualgpu/bin/chromium-dual-gpu-test \
#      --ozone-platform=x11 --user-data-dir="$HOME/.cache/dual-gpu-v6b-intel" \
#      --enable-logging=stderr 2>&1 | tee v6b-intel.log
# Repeat with MODE=nvidia and another profile if dual mode fails. Isolation=0 still
# uses the new handle-scoped dispatch; it is NOT a return to the old unsafe dispatch.
# No zero-NVIDIA-idle expectation applies to NVIDIA-only, isolation=0 or trim=0.
#
# Scope and retained behavior:
# - v4.1 DCSI workaround and latest-content fixes retained; no v5 share-group edits.
# - Per-instance/device dispatch, exclusive single-ICD instances, lazy unloadable
#   NVIDIA references, safe idle teardown and retry-preserving mappings included.
# - Drivers are resolved inside the loader using its canonical manifest discovery;
#   no Nix ICD paths or VK_DRIVER_FILES/VK_ICD_FILENAMES are injected. The generic
#   patched Vulkan loader is a normal runtime dependency independent of Chromium.
# - This Intel/proprietary-NVIDIA prototype recognizes the existing Intel/NVIDIA
#   ICD library names in manifests. Missing, ambiguous or bare-SONAME-only manifest
#   paths fail closed. Actual Vulkan vendor/device identity is checked afterward.
# - Implicit layers and inherited driver override/offload variables are cleared.
#   Explicit validation/API-dump layers are not supported in isolated mode.
# - Independent Chromium Vulkan compositor/WebGPU clients are disabled for these
#   tests; rendering stays on ANGLE/Vulkan. This iteration does not isolate Dawn.
# - Runtime library directories get read-only GPU broker permissions for lazy
#   loading. The GPU sandbox itself remains enabled.
#
# If anything fails, send: preflight log, build's first error OR full browser log,
# FD snapshots at the three stages, GPU PID before/after, test-page output, selected
# runtime controls, backend, power state, and the crash dump if there was a crash.
# Useful log filter: rg 'DUALGPU|ERROR|SIGSEGV|context lost' v6b-x11.log

{ config, lib, pkgs, ... }:

# Home Manager module — v6b, Chromium 153.0.8010.47 / Vulkan loader 1.4.357.0.
# Preserve v4.1 DCSI/latest-content changes. Add handle-scoped Vulkan dispatch,
# exclusive runtime-resolved drivers, lazy NVIDIA teardown, and runtime controls.
# Build preflightPackage first; see the accompanying testing instructions.
# No full Chromium compile or Surface Book hardware validation was possible here.

let
  cfg = config.programs.chromiumDualGpuPrototype;

  # A small independent rebuild. Driver paths are discovered at runtime by
  # the loader itself, never supplied by this Nix module or environment variables.
  dualGpuLoader = assert lib.assertMsg (pkgs.vulkan-loader.version == "1.4.357.0")
    "dual-GPU v6b loader patch targets vulkan-loader 1.4.357.0";
    pkgs.vulkan-loader.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        ${pkgs.python3}/bin/python3 <<'PY'
        from pathlib import Path
        p=Path('loader/loader.c')
        s=p.read_text()
        marker='// Try to find the Vulkan ICD driver(s).'
        assert s.count(marker)==1
        code=r''''
        #if defined(__linux__)
        #include <pthread.h>
        #include <limits.h>
        // Private ABI v1: metadata only. Called before Chromium enters its GPU sandbox.
        // Use the loader's own discovery and manifest parsing; never probe a driver.
        static pthread_once_t dual_gpu_once = PTHREAD_ONCE_INIT;
        static char *dual_gpu_paths[2] = {NULL, NULL};
        static void dual_gpu_discover(void) {
            struct loader_string_list files = {0};
            bool ambiguous[2] = {false, false};
            if (loader_get_data_files(NULL, LOADER_DATA_FILE_MANIFEST_DRIVER, NULL, &files) != VK_SUCCESS)
                return;
            for (uint32_t i = 0; i < files.count; ++i) {
                struct ICDManifestInfo info = {0};
                VkResult result = loader_parse_icd_manifest(NULL, files.list[i], &info, NULL);
                if (result == VK_SUCCESS && info.full_library_path) {
                    const char *base = strrchr(info.full_library_path, '/');
                    base = base ? base + 1 : info.full_library_path;
                    int index = strcmp(base, "libvulkan_intel.so") == 0 ? 0 :
                                strcmp(base, "libGLX_nvidia.so.0") == 0 ? 1 : -1;
                    if (index >= 0) {
                        // This prototype requires a manifest-resolved filesystem path.
                        // Bare SONAME manifests cannot safely grant sandbox permissions.
                        char canonical[PATH_MAX];
                        if (strchr(info.full_library_path, '/') && realpath(info.full_library_path, canonical)) {
                            FILE *file = fopen(canonical, "rb");
                            unsigned char elf[5] = {0};
                            bool compatible = file && fread(elf, 1, sizeof(elf), file) == sizeof(elf) &&
                                memcmp(elf, "\177ELF", 4) == 0 && elf[4] == (sizeof(void *) == 8 ? 2 : 1);
                            if (file) fclose(file);
                            if (compatible) {
                                if (dual_gpu_paths[index] && strcmp(dual_gpu_paths[index], canonical) != 0)
                                    ambiguous[index] = true;
                                else if (!dual_gpu_paths[index])
                                    dual_gpu_paths[index] = strdup(canonical);
                            }
                        }
                    }
                }
                loader_instance_heap_free(NULL, info.full_library_path);
            }
            free_string_list(NULL, &files);
            for (int i = 0; i < 2; ++i) {
                if (ambiguous[i]) {
                    free(dual_gpu_paths[i]);
                    dual_gpu_paths[i] = NULL;
                    fprintf(stderr, "DUALGPU: ambiguous compatible ICD manifests for vendor slot %d\n", i);
                }
            }
        }
        __attribute__((visibility("default"))) const char *vkDualGpuDriverPathCHROMIUM_v1(uint32_t vendor) {
            pthread_once(&dual_gpu_once, dual_gpu_discover);
            return vendor == 0x8086 ? dual_gpu_paths[0] : vendor == 0x10de ? dual_gpu_paths[1] : NULL;
        }
        #endif

        ''''
        p.write_text(s.replace(marker,code+marker))
        PY
      '';
    });

  preflightSource = pkgs.writeText "dual-gpu-preflight.cpp" ''
    #define VK_NO_PROTOTYPES
    #include <vulkan/vulkan.h>
    #include <dlfcn.h>
    #include <cstdio>
    #include <cstdlib>
    #include <cstring>
    #include <vector>
    #include <filesystem>
    #include <string>
    #include <thread>
    static void require(bool condition, const char* what) {
        if (!condition) { std::fprintf(stderr, "FAIL: %s\n", what); std::exit(1); }
    }
    static int nvidiaFDs(const char* stage) {
        int count = 0;
        for (const auto& entry : std::filesystem::directory_iterator("/proc/self/fd")) {
            std::error_code error;
            std::string target = std::filesystem::read_symlink(entry.path(), error).string();
            bool nvidia = target.rfind("/dev/nvidia", 0) == 0;
            if (target.rfind("/dev/dri/", 0) == 0) {
                std::string name = std::filesystem::path(target).filename().string();
                std::string path = "/sys/class/drm/" + name + "/device/vendor";
                FILE* f = std::fopen(path.c_str(), "r");
                unsigned vendor = 0;
                if (f) { if (std::fscanf(f, "%x", &vendor) == 1) nvidia = vendor == 0x10de; std::fclose(f); }
            }
            if (nvidia) { ++count; std::printf("  NVIDIA FD %s -> %s\n", entry.path().filename().c_str(), target.c_str()); }
        }
        std::printf("%s: NVIDIA FDs=%d\n", stage, count);
        return count;
    }
    struct Driver {
        void* library = nullptr;
        VkInstance instance = VK_NULL_HANDLE;
        VkDevice device = VK_NULL_HANDLE;
        PFN_vkGetInstanceProcAddr gipa = nullptr;
        PFN_vkDeviceWaitIdle idle = nullptr;
        PFN_vkDestroyDevice destroyDevice = nullptr;
        PFN_vkDestroyInstance destroyInstance = nullptr;
        void open(uint32_t vendor, const char* path, PFN_vkGetInstanceProcAddr loaderGIPA) {
            require(path, "no unique compatible canonical driver manifest");
            library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
            if (!library) std::fprintf(stderr, "%s\n", dlerror());
            require(library, "dlopen selected ICD");
            auto driverGIPA = reinterpret_cast<PFN_vkGetInstanceProcAddr>(dlsym(library, "vk_icdGetInstanceProcAddr"));
            require(driverGIPA, "ICD GIPA");
            using Negotiate = VkResult (*)(uint32_t*);
            auto negotiate = reinterpret_cast<Negotiate>(dlsym(library, "vk_icdNegotiateLoaderICDInterfaceVersion"));
            uint32_t interfaceVersion = 7;
            require(negotiate && negotiate(&interfaceVersion) == VK_SUCCESS && interfaceVersion >= 7,
                    "ICD interface version 7 required by ANGLE isolation");
            auto enumerateExtensions = reinterpret_cast<PFN_vkEnumerateInstanceExtensionProperties>(
                driverGIPA(nullptr, "vkEnumerateInstanceExtensionProperties"));
            uint32_t extensionCount = 0;
            require(enumerateExtensions && enumerateExtensions(nullptr, &extensionCount, nullptr) == VK_SUCCESS,
                    "selected ICD extension enumeration");
            gipa = loaderGIPA;
            VkDirectDriverLoadingInfoLUNARG direct{VK_STRUCTURE_TYPE_DIRECT_DRIVER_LOADING_INFO_LUNARG};
            direct.pfnGetInstanceProcAddr = driverGIPA;
            VkDirectDriverLoadingListLUNARG list{VK_STRUCTURE_TYPE_DIRECT_DRIVER_LOADING_LIST_LUNARG};
            list.mode = VK_DIRECT_DRIVER_LOADING_MODE_EXCLUSIVE_LUNARG;
            list.driverCount = 1; list.pDrivers = &direct;
            const char* extension = VK_LUNARG_DIRECT_DRIVER_LOADING_EXTENSION_NAME;
            VkApplicationInfo app{VK_STRUCTURE_TYPE_APPLICATION_INFO}; app.apiVersion = VK_API_VERSION_1_1;
            VkInstanceCreateInfo ci{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
            ci.pNext = &list; ci.pApplicationInfo = &app; ci.enabledExtensionCount = 1; ci.ppEnabledExtensionNames = &extension;
            auto create = reinterpret_cast<PFN_vkCreateInstance>(gipa(nullptr, "vkCreateInstance"));
            VkResult result = create(&ci, nullptr, &instance);
            std::printf("vendor=%04x exclusive instance result=%d\n", vendor, result);
            require(result == VK_SUCCESS, "exclusive vkCreateInstance");
            auto enumerate = reinterpret_cast<PFN_vkEnumeratePhysicalDevices>(gipa(instance, "vkEnumeratePhysicalDevices"));
            auto properties = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties>(gipa(instance, "vkGetPhysicalDeviceProperties"));
            uint32_t count = 0; require(enumerate(instance, &count, nullptr) == VK_SUCCESS && count, "physical device count");
            std::vector<VkPhysicalDevice> devices(count);
            require(enumerate(instance, &count, devices.data()) == VK_SUCCESS, "enumerate devices");
            VkPhysicalDevice physical = nullptr;
            for (auto candidate : devices) {
                VkPhysicalDeviceProperties p{}; properties(candidate, &p);
                std::printf("  vendor=%04x device=%04x %s\n", p.vendorID, p.deviceID, p.deviceName);
                require(p.vendorID == vendor, "exclusive instance exposed wrong vendor"); physical = candidate;
            }
            auto queues = reinterpret_cast<PFN_vkGetPhysicalDeviceQueueFamilyProperties>(gipa(instance, "vkGetPhysicalDeviceQueueFamilyProperties"));
            queues(physical, &count, nullptr); std::vector<VkQueueFamilyProperties> families(count); queues(physical, &count, families.data());
            uint32_t family = 0; while (family < count && !(families[family].queueFlags & VK_QUEUE_GRAPHICS_BIT)) ++family;
            require(family < count, "graphics queue");
            float priority = 1; VkDeviceQueueCreateInfo qi{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO};
            qi.queueFamilyIndex = family; qi.queueCount = 1; qi.pQueuePriorities = &priority;
            VkDeviceCreateInfo di{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO}; di.queueCreateInfoCount = 1; di.pQueueCreateInfos = &qi;
            auto createDevice = reinterpret_cast<PFN_vkCreateDevice>(gipa(instance, "vkCreateDevice"));
            require(createDevice(physical, &di, nullptr, &device) == VK_SUCCESS, "vkCreateDevice");
            auto gdpa = reinterpret_cast<PFN_vkGetDeviceProcAddr>(gipa(instance, "vkGetDeviceProcAddr"));
            idle = reinterpret_cast<PFN_vkDeviceWaitIdle>(gdpa(device, "vkDeviceWaitIdle"));
            destroyDevice = reinterpret_cast<PFN_vkDestroyDevice>(gdpa(device, "vkDestroyDevice"));
            destroyInstance = reinterpret_cast<PFN_vkDestroyInstance>(gipa(instance, "vkDestroyInstance"));
        }
        void exercise() { for (int i = 0; i < 1000; ++i) require(idle(device) == VK_SUCCESS, "device wait idle"); }
        void close() { if (device) { require(idle(device) == VK_SUCCESS, "final wait"); destroyDevice(device, nullptr); device = nullptr; }
            if (instance) { destroyInstance(instance, nullptr); instance = nullptr; } if (library) { dlclose(library); library = nullptr; } }
    };
    int main(int argc, char** argv) {
        setenv("VK_LOADER_LAYERS_DISABLE", "~implicit~", 1);
        for (const char* key : {"VK_DRIVER_FILES", "VK_ICD_FILENAMES", "VK_ADD_DRIVER_FILES", "VK_INSTANCE_LAYERS"}) unsetenv(key);
        void* loader = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL); require(loader, "open private Vulkan loader");
        using Resolver = const char* (*)(uint32_t);
        auto resolve = reinterpret_cast<Resolver>(dlsym(loader, "vkDualGpuDriverPathCHROMIUM_v1"));
        auto gipa = reinterpret_cast<PFN_vkGetInstanceProcAddr>(dlsym(loader, "vkGetInstanceProcAddr"));
        require(resolve && gipa, "private resolver ABI v1");
        const char* intelPath = resolve(0x8086); const char* nvidiaPath = resolve(0x10de);
        std::printf("Metadata: Intel=%s NVIDIA=%s\n", intelPath ? "found" : "missing", nvidiaPath ? "found" : "missing");
        require(nvidiaFDs("metadata only") == 0, "metadata discovery opened NVIDIA");
        if (argc > 1 && std::strcmp(argv[1], "--metadata-only") == 0) return intelPath && nvidiaPath ? 0 : 1;
        Driver intel; intel.open(0x8086, intelPath, gipa);
        require(nvidiaFDs("Intel only") == 0, "Intel instance opened NVIDIA");
        for (int cycle = 0; cycle < 3; ++cycle) {
            Driver nvidia; nvidia.open(0x10de, nvidiaPath, gipa);
            std::thread a([&] { intel.exercise(); }), b([&] { nvidia.exercise(); }); a.join(); b.join();
            nvidia.close(); require(nvidiaFDs("after NVIDIA teardown") == 0, "NVIDIA driver retained FDs after teardown");
            intel.exercise();
        }
        intel.close(); puts("PASS: discovery, isolation, concurrent devices, three NVIDIA teardown/recreate cycles");
    }
  '';
  preflight = pkgs.runCommandCC "chromium-dual-gpu-preflight-v6b" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    buildInputs = [ pkgs.vulkan-headers ];
  } ''
    mkdir -p "$out/bin"
    $CXX -std=c++20 -O2 -pthread ${preflightSource} -ldl -o "$out/bin/dual-gpu-preflight"
    wrapProgram "$out/bin/dual-gpu-preflight" \
      --prefix LD_LIBRARY_PATH : ${lib.getLib dualGpuLoader}/lib
  '';

  # Keep this deliberately separate from the user's normal Chromium.
  # These flags force WebGL through ANGLE/Vulkan so ANGLE can explicitly
  # choose a VkPhysicalDevice.
  chromiumArgs = [
    "--use-gl=angle"
    "--use-angle=vulkan"
    "--ozone-platform=wayland"
    # Keep other Vulkan clients from doing loader-wide GPU discovery.
    "--disable-features=Vulkan,WebGPUService,SkiaGraphite"
    "--disable-skia-graphite"
    "--enable-features=EGLDualGPURendering,WaylandWindowDecorations,UseDynamicBackingAllocations"
    "--enable-wayland-ime=true"
  ] ++ cfg.extraArgs;

  baseChromium = cfg.package.override {
    commandLineArgs = lib.escapeShellArgs chromiumArgs;
  };

  originalBrowser = baseChromium.browser;

  patchedBrowser = assert lib.assertMsg (originalBrowser.version == "153.0.8010.47")
    "dual-GPU v6b targets Chromium 153.0.8010.47; review patches before changing this guard";
    originalBrowser.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      echo "Applying Chromium Linux dual-GPU WebGL prototype v6b patch"

      ${pkgs.python3}/bin/python3 <<'PY'
      from pathlib import Path
      import sys

      def replace_once(path, old, new, description):
          path = Path(path)
          text = path.read_text()
          count = text.count(old)
          if count != 1:
              print(
                  f"dual-gpu patch: expected exactly one match for {description} "
                  f"in {path}, found {count}",
                  file=sys.stderr,
              )
              sys.exit(1)
          path.write_text(text.replace(old, new, 1))
          print(f"dual-gpu patch: {description}")

      def replace_one_of(path, replacements, description):
          path = Path(path)
          text = path.read_text()
          matches = [(old, new) for old, new in replacements if old in text]
          if len(matches) != 1:
              print(
                  f"dual-gpu patch: expected exactly one source form for "
                  f"{description} in {path}, found {len(matches)}",
                  file=sys.stderr,
              )
              sys.exit(1)
          old, new = matches[0]
          path.write_text(text.replace(old, new, 1))
          print(f"dual-gpu patch: {description}")

      # 1. Chromium currently exposes EGLDualGPURendering only on Win/Mac.
      replace_one_of(
          "ui/gl/gl_switches.cc",
          [
              (
                  """bool SupportsEGLDualGPURendering() {
      #if BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC)
      """,
                  """bool SupportsEGLDualGPURendering() {
      #if BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX)
      """,
              ),
              (
                  """bool SupportsEGLDualGPURendering() {
      #if defined(USE_EGL) && (BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC))
      """,
                  """bool SupportsEGLDualGPURendering() {
      #if defined(USE_EGL) && (BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX))
      """,
              ),
          ],
          "enable EGLDualGPURendering support on Linux",
      )

      # 2. Compile Chromium's EGL GPU preference/display setup on Linux.
      replace_one_of(
          "gpu/ipc/service/gpu_init.cc",
          [
              (
                  """#if BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC)
      const GPUInfo::GPUDevice* GetDefaultGPU(
      """,
                  """#if BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX)
      const GPUInfo::GPUDevice* GetDefaultGPU(
      """,
              ),
              (
                  """#if defined(USE_EGL) && (BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC))
      const GPUInfo::GPUDevice* GetDefaultGPU(
      """,
                  """#if defined(USE_EGL) && (BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX))
      const GPUInfo::GPUDevice* GetDefaultGPU(
      """,
              ),
          ],
          "compile EGL display-manager setup on Linux",
      )

      # Linux's GPUInfo does not currently assign low/high-power preferences in
      # the way macOS does.  For this prototype, explicitly classify Intel as
      # low/default and NVIDIA as high-performance.
      replace_once(
          "gpu/ipc/service/gpu_init.cc",
          """  const GPUInfo::GPUDevice* gpu_high_perf =
            gpu_info.GetGpuByPreference(gl::GpuPreference::kHighPerformance);
        const GPUInfo::GPUDevice* gpu_low_power =
            gpu_info.GetGpuByPreference(gl::GpuPreference::kLowPower);
      """,
          """#if BUILDFLAG(IS_LINUX)
        const GPUInfo::GPUDevice* gpu_high_perf = nullptr;
        const GPUInfo::GPUDevice* gpu_low_power = nullptr;

        auto classify_gpu = [&](const GPUInfo::GPUDevice& gpu) {
          // Intel PCI vendor ID.
          if (gpu.vendor_id == 0x8086) {
            gpu_low_power = &gpu;
          }
          // NVIDIA PCI vendor ID.
          if (gpu.vendor_id == 0x10de) {
            gpu_high_perf = &gpu;
          }
        };

        classify_gpu(gpu_info.gpu);
        for (const auto& gpu : gpu_info.secondary_gpus) {
          classify_gpu(gpu);
        }
      #else
        const GPUInfo::GPUDevice* gpu_high_perf =
          gpu_info.GetGpuByPreference(gl::GpuPreference::kHighPerformance);
        const GPUInfo::GPUDevice* gpu_low_power =
          gpu_info.GetGpuByPreference(gl::GpuPreference::kLowPower);
      #endif
      """,
          "classify Intel/NVIDIA GPUs on Linux",
      )

      # ANGLE/Vulkan accepts EGL_PLATFORM_ANGLE_DEVICE_ID_{HIGH,LOW}_ANGLE.
      # For its Vulkan backend, Chromium's 64-bit selector is interpreted as:
      #   high 32 bits = PCI vendor ID
      #   low  32 bits = PCI device ID
      replace_once(
          "gpu/ipc/service/gpu_init.cc",
          """#else  // IS_MAC
        const GPUInfo::GPUDevice* gpu_default =
            gpu_low_power ? gpu_low_power : GetDefaultGPU(gpu_info, gpu_feature_info);
        uint64_t system_device_id_high_perf =
            gpu_high_perf ? gpu_high_perf->system_device_id : 0;
        uint64_t system_device_id_low_power =
            gpu_low_power ? gpu_low_power->system_device_id : 0;
        uint64_t system_device_id_default = gpu_default->system_device_id;
      #endif  // BUILDFLAG(IS_WIN)
      """,
          """#elif BUILDFLAG(IS_LINUX)
        // This prototype intentionally prefers Intel for Chromium/default WebGL
        // and NVIDIA only for an explicit high-performance WebGL context.
        const GPUInfo::GPUDevice* gpu_default =
            gpu_low_power ? gpu_low_power : GetDefaultGPU(gpu_info, gpu_feature_info);

        auto angle_vulkan_device_selector =
            [](const GPUInfo::GPUDevice* gpu) -> uint64_t {
          if (!gpu) {
            return 0;
          }
          return (static_cast<uint64_t>(gpu->vendor_id) << 32) |
                 static_cast<uint64_t>(gpu->device_id);
        };

        uint64_t system_device_id_high_perf =
            angle_vulkan_device_selector(gpu_high_perf);
        uint64_t system_device_id_low_power =
            angle_vulkan_device_selector(gpu_low_power);
        uint64_t system_device_id_default =
            angle_vulkan_device_selector(gpu_default);
      #else  // IS_MAC
        const GPUInfo::GPUDevice* gpu_default =
            gpu_low_power ? gpu_low_power : GetDefaultGPU(gpu_info, gpu_feature_info);
        uint64_t system_device_id_high_perf =
            gpu_high_perf ? gpu_high_perf->system_device_id : 0;
        uint64_t system_device_id_low_power =
            gpu_low_power ? gpu_low_power->system_device_id : 0;
        uint64_t system_device_id_default = gpu_default->system_device_id;
      #endif  // BUILDFLAG(IS_WIN)
      """,
          "map Linux GPU preferences to ANGLE Vulkan vendor/device selectors",
      )

      replace_one_of(
          "gpu/ipc/service/gpu_init.cc",
          [
              (
                  """#if BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC)
        SetupGLDisplayManagerEGL(gpu_info_, gpu_feature_info_);
      #endif  // IS_WIN || IS_MAC
      """,
                  """#if BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX)
        SetupGLDisplayManagerEGL(gpu_info_, gpu_feature_info_);
      #endif  // IS_WIN || IS_MAC || IS_LINUX
      """,
              ),
              (
                  """#if defined(USE_EGL) && (BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC))
        SetupGLDisplayManagerEGL(gpu_info_, gpu_feature_info_);
      #endif  // USE_EGL && (IS_WIN || IS_MAC)
      """,
                  """#if defined(USE_EGL) && (BUILDFLAG(IS_WIN) || BUILDFLAG(IS_MAC) || BUILDFLAG(IS_LINUX))
        SetupGLDisplayManagerEGL(gpu_info_, gpu_feature_info_);
      #endif  // USE_EGL && (IS_WIN || IS_MAC || IS_LINUX)
      """,
              ),
          ],
          "initialize EGL display-manager GPU mappings on Linux",
      )

      # 3. Chromium currently permits the second EGL display only for
      # ANGLE/Metal.  Let ANGLE/Vulkan use the same path.
      replace_once(
          "gpu/ipc/service/gles2_command_buffer_stub.cc",
          """  if (gl::GetGLImplementation() == gl::kGLImplementationEGLANGLE &&
            gl::GetANGLEImplementation() == gl::ANGLEImplementation::kMetal &&
            features::SupportsEGLDualGPURendering()) {
      """,
          """  if (gl::GetGLImplementation() == gl::kGLImplementationEGLANGLE &&
            (gl::GetANGLEImplementation() == gl::ANGLEImplementation::kMetal ||
             gl::GetANGLEImplementation() == gl::ANGLEImplementation::kVulkan) &&
            features::SupportsEGLDualGPURendering()) {
      """,
          "allow ANGLE/Vulkan to create the high-performance EGL display",
      )

      # Chromium M153 already has the WebGL semantics we want:
      #   default/low-power -> kLowPower
      #   high-performance  -> kHighPerformance
      #
      # The remaining Linux problem is SharedImage routing. A high-performance
      # WebGL DrawingBuffer is tagged with
      # SHARED_IMAGE_USAGE_HIGH_PERFORMANCE_GPU, but CompoundImageBacking wraps
      # the initially-created (default-GPU/Ozone) backing with ALL access
      # streams, including kGL. That lets the NVIDIA GL context try to reuse the
      # Intel/Ozone backing instead of asking DCSI for a GPU-local GL backing.
      #
      # Prototype fix: for a high-performance SharedImage, do not advertise the
      # initial backing as a kGL backing. With UseDynamicBackingAllocations
      # enabled, the first kGL access must then dynamically allocate a backing
      # while the high-performance ANGLE/Vulkan context is current.
      replace_once(
          "gpu/command_buffer/service/shared_image/compound_image_backing.cc",
          """  element.access_streams = AccessStreamSet::All();

        // |backing| may have a cleared rect set""",
          """  element.access_streams = AccessStreamSet::All();

      #if BUILDFLAG(IS_LINUX)
        if (usage().Has(SHARED_IMAGE_USAGE_HIGH_PERFORMANCE_GPU)) {
          LOG(ERROR) << "DUALGPU: high-performance SharedImage: "
                        "removing kGL from initial backing "
                     << backing->GetName();
          element.access_streams.Remove(SharedImageAccessStream::kGL);
        }
      #endif

        // |backing| may have a cleared rect set""",
          "force high-performance GL through a dynamically allocated backing",
      )

      # Keep v3's known-good GL routing unchanged.
      #
      # Backport upstream Chromium commit
      # f1ca08ec7e806878ea916776bc3114b438333efe (2026-09-17):
      # when DCSI has multiple GPU backings, readback must select the backing
      # that actually owns latest_content_id_, rather than simply the first
      # non-memory backing.

      replace_once(
          "gpu/command_buffer/service/shared_image/compound_image_backing.cc",
          """  auto* gpu_backing = GetGpuBacking();
        if (!gpu_backing ||
            !copy_manager_->CopyImage(gpu_backing, shm_element.GetBacking())) {
          LOG(ERROR) << "Failed to copy from GPU backing (" << gpu_backing->GetName()
                     << ") to shared memory";
          return false;
        }
      """,
          """  auto* gpu_backing = GetGpuBacking();
        if (!gpu_backing) {
          LOG(ERROR) << "Failed to copy from GPU backing to shared memory: no GPU "
                        "backing with latest content";
          return false;
        }
        if (!copy_manager_->CopyImage(gpu_backing, shm_element.GetBacking())) {
          LOG(ERROR) << "Failed to copy from GPU backing (" << gpu_backing->GetName()
                     << ") to shared memory";
          return false;
        }
      """,
          "backport upstream latest-content synchronous readback fix",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/compound_image_backing.cc",
          """  auto* gpu_backing = GetGpuBacking();
        if (!gpu_backing) {
          LOG(ERROR) << "Failed to copy from GPU backing (" << gpu_backing->GetName()
                     << ") to shared memory";
          std::move(callback).Run(false);
          return;
        }
      """,
          """  auto* gpu_backing = GetGpuBacking();
        if (!gpu_backing) {
          LOG(ERROR) << "Failed to copy from GPU backing to shared memory: no GPU "
                        "backing with latest content";
          std::move(callback).Run(false);
          return;
        }
      """,
          "backport upstream latest-content asynchronous readback null guard",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/compound_image_backing.cc",
          """SharedImageBacking* CompoundImageBacking::GetGpuBacking() {
        for (auto& element : elements_) {
          if (!element.access_streams.Has(SharedImageAccessStream::kMemory)) {
            return element.GetBacking();
          }
        }
        LOG(ERROR) << "No GPU backing found.";
        return nullptr;
      }
      """,
          """SharedImageBacking* CompoundImageBacking::GetGpuBacking() {
        for (auto& element : elements_) {
          if (!element.access_streams.Has(SharedImageAccessStream::kMemory) &&
              HasLatestContent(element) && element.GetBacking()) {
            return element.GetBacking();
          }
        }
        LOG(ERROR) << "No GPU backing with latest content found.";
        return nullptr;
      }
      """,
          "backport upstream latest-content GPU backing selection fix",
      )

      print("dual-gpu patch v4.1: all prototype edits applied successfully")


      from pathlib import Path
      import re
      import xml.etree.ElementTree as ET

      root = Path('.')
      volk = root/'third_party/angle/src/third_party/volk'
      original = (volk/'volk.c').read_text()
      block = original.split('/* VOLK_GENERATE_PROTOTYPES_C */')[1]
      xml = ET.parse(root/'third_party/vulkan-headers/src/registry/vk.xml').getroot()
      commands = {}
      for c in xml.find('commands'):
          if c.tag != 'command' or 'vulkan' not in c.get('api','vulkan').split(','): continue
          n = c.get('name') if c.get('alias') else c.findtext('proto/name')
          commands[n] = c

      def canonical(n):
          while commands[n].get('alias'): n = commands[n].get('alias')
          return n
      aliases = {}
      for n in commands: aliases.setdefault(canonical(n),[]).append(n)

      def description(n):
          c=commands[canonical(n)]
          ps=[p for p in c.findall('param') if 'vulkan' in p.get('api','vulkan').split(',')]
          return c.findtext('proto/type'), ', '.join('''.join(p.itertext()).strip() for p in ps) or 'void', ', '.join(p.findtext('name') for p in ps), ps

      pat=re.compile(r'PFN_(vk\w+) \1;')
      names=pat.findall(block)
      assert len(names)==len(set(names))

      def transform(fn):return pat.sub(lambda m:fn(m[1]),block)
      fields=transform(lambda n:f'PFN_{n} {n} = nullptr;')
      loads=transform(lambda n:'\n'.join([f'    record->{n} = reinterpret_cast<PFN_{n}>(resolve("{n}"));']+[f'    if (!record->{n}) record->{n} = reinterpret_cast<PFN_{n}>(resolve("{a}"));' for a in aliases[canonical(n)] if a!=n]))

      prefix=r''''// Generated from the exact checkout's Vulkan registry and Volk command list.
      // Stable entry points; instance/device tables never overwrite one another.
      #include "volk.h"
      #include <atomic>
      #include <cstdint>
      #include <cstdio>
      #include <cstdlib>
      #include <cstring>
      #include <dlfcn.h>
      #include <memory>
      #include <mutex>
      #include <unordered_map>

      namespace {
      struct Dispatch {
      ''''+fields+r''''
      };
      struct Registry {
          std::mutex mutex;
          std::unordered_map<void*, std::shared_ptr<Dispatch>> records;
          std::atomic<uint64_t> generation{1};
          std::once_flag initialize;
          PFN_vkGetInstanceProcAddr gipa = nullptr;
          std::shared_ptr<Dispatch> global;
          void* loader = nullptr;
      };
      Registry& registry() { static auto* value = new Registry; return *value; }
      // Vulkan loader/layer ABI: dispatchable handles begin with their dispatch-table
      // pointer. Device, queue and command-buffer handles use their device's key.
      // Returned physical devices and child handles are registered too, for layers
      // that use distinct dispatch keys for those handle classes.
      template<class Handle> void* key(Handle handle) {
          void* value = nullptr;
          if (handle) std::memcpy(&value, reinterpret_cast<const void*>(handle), sizeof(value));
          return value;
      }
      [[noreturn]] void fail(const char* name) {
          std::fprintf(stderr, "DUALGPU: missing dispatch for %s\n", name);
          std::abort();
      }
      template<class Handle> std::shared_ptr<Dispatch> lookup(Handle handle) {
          struct Cache { void* key = nullptr; uint64_t generation = 0; std::shared_ptr<Dispatch> value; };
          static thread_local Cache cache;
          auto& r = registry();
          void* k = key(handle);
          auto epoch = r.generation.load(std::memory_order_acquire);
          if (cache.key == k && cache.generation == epoch && cache.value) return cache.value;
          std::lock_guard<std::mutex> lock(r.mutex);
          auto it = r.records.find(k);
          if (it == r.records.end()) fail("unregistered dispatchable handle");
          cache = {k, r.generation.load(std::memory_order_relaxed), it->second};
          return cache.value;
      }
      template<class Handle> void attach(Handle handle, const std::shared_ptr<Dispatch>& record) {
          if (!handle) return;
          auto& r = registry();
          std::lock_guard<std::mutex> lock(r.mutex);
          auto k = key(handle);
          auto it = r.records.find(k);
          if (it != r.records.end() && it->second == record) return;
          if (it != r.records.end()) fail("duplicate live dispatch key");
          r.records.emplace(k, record);
          r.generation.fetch_add(1, std::memory_order_release);
      }
      void forget(const std::shared_ptr<Dispatch>& record) {
          auto& r = registry();
          std::lock_guard<std::mutex> lock(r.mutex);
          for (auto it=r.records.begin(); it!=r.records.end();) {
              if (it->second == record) it=r.records.erase(it); else ++it;
          }
          r.generation.fetch_add(1, std::memory_order_release);
      }
      std::shared_ptr<Dispatch> makeRecord(VkInstance instance, VkDevice device,
                                         PFN_vkGetDeviceProcAddr gdpa) {
          auto record = std::make_shared<Dispatch>();
          auto resolve = [&](const char* name) {
              if (!device && !instance && std::strcmp(name, "vkCreateInstance") != 0 &&
                  std::strcmp(name, "vkEnumerateInstanceExtensionProperties") != 0 &&
                  std::strcmp(name, "vkEnumerateInstanceLayerProperties") != 0 &&
                  std::strcmp(name, "vkEnumerateInstanceVersion") != 0 &&
                  std::strcmp(name, "vkGetInstanceProcAddr") != 0)
                  return PFN_vkVoidFunction(nullptr);
              return device ? gdpa(device, name) : registry().gipa(instance, name);
          };
      ''''+loads+r''''
          record->vkGetInstanceProcAddr = registry().gipa;
          if (device) record->vkGetDeviceProcAddr = gdpa;
          return record;
      }
      thread_local VkInstance lastInstance = VK_NULL_HANDLE;
      thread_local VkDevice lastDevice = VK_NULL_HANDLE;
      ''''

      def wrapper(n):
          ret,params,args,ps=description(n)
          first=ps[0].findtext('name') if ps else '''
          typ=ps[0].findtext('type') if ps else '''
          if n=='vkGetInstanceProcAddr':
              body=f'    return registry().gipa({args});'
          else:
              dispatch=typ in ('VkDevice','VkQueue','VkCommandBuffer','VkInstance','VkPhysicalDevice')
              body=f'    auto record = lookup({first});' if dispatch else '    auto record = registry().global;'
              body+=f'\n    if (!record || !record->{n}) fail("{n}");'
              call=f'record->{n}({args})'
              if ret=='void':body+=f'\n    {call};'
              else:body+=f'\n    auto result = {call};'
              if n=='vkCreateInstance':body+='\n    if (result == VK_SUCCESS) attach(*pInstance, makeRecord(*pInstance, VK_NULL_HANDLE, nullptr));'
              elif n=='vkCreateDevice':body+='\n    if (result == VK_SUCCESS) attach(*pDevice, makeRecord(VK_NULL_HANDLE, *pDevice, record->vkGetDeviceProcAddr));'
              elif n=='vkEnumeratePhysicalDevices':body+='\n    if ((result == VK_SUCCESS || result == VK_INCOMPLETE) && pPhysicalDevices)\n        for (uint32_t i=0; i<*pPhysicalDeviceCount; ++i) attach(pPhysicalDevices[i], record);'
              elif n in ('vkEnumeratePhysicalDeviceGroups','vkEnumeratePhysicalDeviceGroupsKHR'):
                  body+='\n    if ((result == VK_SUCCESS || result == VK_INCOMPLETE) && pPhysicalDeviceGroupProperties)\n        for (uint32_t i=0; i<*pPhysicalDeviceGroupCount; ++i)\n            for (uint32_t j=0; j<pPhysicalDeviceGroupProperties[i].physicalDeviceCount; ++j)\n                attach(pPhysicalDeviceGroupProperties[i].physicalDevices[j], record);'
              elif n in ('vkGetDeviceQueue','vkGetDeviceQueue2'):body+='\n    attach(*pQueue, record);'
              elif n=='vkAllocateCommandBuffers':body+='\n    if (result == VK_SUCCESS)\n        for (uint32_t i=0; i<pAllocateInfo->commandBufferCount; ++i) attach(pCommandBuffers[i], record);'
              elif n in ('vkDestroyDevice','vkDestroyInstance'):body+='\n    forget(record);'
              if ret!='void':body+='\n    return result;'
          return f'static VKAPI_ATTR {ret} VKAPI_CALL dispatch_{n}({params}) {{\n{body}\n}}'

      code=prefix+transform(wrapper)+'\n} // namespace\n'
      code+=transform(lambda n:f'PFN_{n} {n} = dispatch_{n};')
      code+=r''''
      void volkInitializeCustom(PFN_vkGetInstanceProcAddr handler) {
          auto& r = registry();
          std::call_once(r.initialize, [&] {
              if (!handler) fail("vkGetInstanceProcAddr");
              r.gipa = handler;
              // Keep the loader, not any ICD, alive for the immutable entry points.
              Dl_info info{};
              if (dladdr(reinterpret_cast<void*>(handler), &info) && info.dli_fname)
                  r.loader = dlopen(info.dli_fname, RTLD_NOW | RTLD_LOCAL);
              r.global = makeRecord(VK_NULL_HANDLE, VK_NULL_HANDLE, nullptr);
              std::fprintf(stderr, "DUALGPU: immutable Vulkan dispatch installed\n");
          });
          if (r.gipa != handler) fail("multiple Vulkan loaders in ANGLE");
      }
      VkResult volkInitialize(void) {
          void* library = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL);
          if (!library) return VK_ERROR_INITIALIZATION_FAILED;
          auto handler = reinterpret_cast<PFN_vkGetInstanceProcAddr>(dlsym(library,"vkGetInstanceProcAddr"));
          if (handler) volkInitializeCustom(handler);
          dlclose(library);
          return handler ? VK_SUCCESS : VK_ERROR_INITIALIZATION_FAILED;
      }
      void volkFinalize(void) { /* Other renderers may still be using the loader. */ }
      uint32_t volkGetInstanceVersion(void) {
          uint32_t version=VK_API_VERSION_1_0;
          auto fn=registry().global->vkEnumerateInstanceVersion;
          if (fn && fn(&version)!=VK_SUCCESS) return 0;
          return version;
      }
      void volkLoadInstance(VkInstance instance) { lastInstance=instance; }
      void volkLoadInstanceOnly(VkInstance instance) { lastInstance=instance; }
      void volkLoadDevice(VkDevice device) { lastDevice=device; }
      VkInstance volkGetLoadedInstance(void) { return lastInstance; }
      VkDevice volkGetLoadedDevice(void) { return lastDevice; }
      void volkLoadDeviceTable(VolkDeviceTable* table, VkDevice device) {
          auto record=lookup(device);
          std::memset(table,0,sizeof(*table));
      ''''
      tableblock=original.split('/* VOLK_GENERATE_LOAD_DEVICE_TABLE */')[1]
      tableblock=re.sub(r'table->(vk\w+) = \(PFN_\1\)load\(context, "\1"\);',lambda m:f'table->{m[1]} = record->{m[1]};',tableblock)
      assert 'load(context,' not in tableblock
      code+=tableblock+'\n}\n'
      (volk/'dual_gpu_volk.cpp').write_text(code)
      print(f'Generated {len(names)} immutable dispatch entry points ({len(code)} bytes)')


      from pathlib import Path
      import re
      root = Path('.')
      def replace(path, old, new):
          p=root/path;s=p.read_text()
          if s.count(old)!=1: raise RuntimeError(f'{path}: expected one match, got {s.count(old)}: {old[:100]!r}')
          p.write_text(s.replace(old,new,1))
      def prepend(path, text):
          p=root/path;p.write_text(text+p.read_text())
      def replace_function(path, signature, body):
          p=root/path;s=p.read_text();start=s.index(signature);a=s.index('{',start);b=s.index('\n}',a)+2
          p.write_text(s[:a]+'{\n'+body+'\n}'+s[b:])
      A='third_party/angle/'
      R=A+'src/libANGLE/renderer/vulkan/vk_renderer.cpp'
      H=A+'src/libANGLE/renderer/vulkan/vk_renderer.h'
      replace(A+'src/third_party/volk/BUILD.gn','"volk.c",','"dual_gpu_volk.cpp",')
      # Table alias resolution replaces all writes to global extension entry points.
      p=root/(A+'src/libANGLE/renderer/vulkan/vk_utils.cpp')
      s=p.read_text()
      for m in list(re.finditer(r'void (Init\w+From(?:Core|KHR))\(\)\n\{.*?\n\}',s,re.S))[::-1]:
          s=s[:m.start()]+f'void {m[1]}()\n{{\n    // Aliases are resolved independently in each immutable dispatch table.\n}}'+s[m.end():]
      p.write_text(s)
      replace_function(R,'void Renderer::reloadVolkIfNeeded() const','    // Every Vulkan handle dispatches through its own immutable table.')
      replace(H,'    void *mLibVulkanLibrary;',''''    void *mLibVulkanLibrary;
          // Resolved by the Vulkan loader from canonical runtime manifest metadata.
          void *mDualGpuDriverLibrary = nullptr;
          PFN_vkGetInstanceProcAddr mDualGpuDriverGIPA = nullptr;
          PFN_vkEnumerateInstanceExtensionProperties mDualGpuEnumerateExtensions = nullptr;'''')
      replace(R,'    mGlobalOps = globalOps;',''''    mGlobalOps = globalOps;
      #if defined(ANGLE_PLATFORM_LINUX) && !defined(ANGLE_PLATFORM_ANDROID)
          const bool isolateDriver = desiredICD == angle::vk::ICD::Default &&
              angle::GetEnvironmentVar("CHROMIUM_DUAL_GPU_ISOLATION") != "0";
          if (isolateDriver)
          {
              using ResolveDriver = const char *(*)(uint32_t);
              auto resolveDriver = reinterpret_cast<ResolveDriver>(angle::GetLibrarySymbol(
                  mLibVulkanLibrary, "vkDualGpuDriverPathCHROMIUM_v1"));
              if (!resolveDriver)
                  ERR() << "DUALGPU: private metadata resolver missing from Vulkan loader";
              ANGLE_VK_CHECK(context, resolveDriver != nullptr, VK_ERROR_INCOMPATIBLE_DRIVER);
              const char *soname = resolveDriver(preferredVendorId);
              if (!soname)
                  ERR() << "DUALGPU: no unique compatible driver manifest for vendor " << preferredVendorId;
              ANGLE_VK_CHECK(context, soname != nullptr, VK_ERROR_INCOMPATIBLE_DRIVER);
              std::string driverError;
              mDualGpuDriverLibrary = angle::OpenSystemLibraryWithExtensionAndGetError(
                  soname, angle::SearchType::SystemDir, &driverError);
              if (!mDualGpuDriverLibrary)
                  ERR() << "DUALGPU: failed to load " << soname << ": " << driverError;
              ANGLE_VK_CHECK(context, mDualGpuDriverLibrary != nullptr, VK_ERROR_INCOMPATIBLE_DRIVER);
              mDualGpuDriverGIPA = reinterpret_cast<PFN_vkGetInstanceProcAddr>(
                  angle::GetLibrarySymbol(mDualGpuDriverLibrary, "vk_icdGetInstanceProcAddr"));
              ANGLE_VK_CHECK(context, mDualGpuDriverGIPA != nullptr, VK_ERROR_INCOMPATIBLE_DRIVER);
              using Negotiate = VkResult (*)(uint32_t *);
              auto negotiate = reinterpret_cast<Negotiate>(angle::GetLibrarySymbol(
                  mDualGpuDriverLibrary, "vk_icdNegotiateLoaderICDInterfaceVersion"));
              ANGLE_VK_CHECK(context, negotiate != nullptr, VK_ERROR_INCOMPATIBLE_DRIVER);
              uint32_t interfaceVersion = 7;
              ANGLE_VK_TRY(context, negotiate(&interfaceVersion));
              ANGLE_VK_CHECK(context, interfaceVersion >= 7, VK_ERROR_INCOMPATIBLE_DRIVER);
              mDualGpuEnumerateExtensions = reinterpret_cast<PFN_vkEnumerateInstanceExtensionProperties>(
                  mDualGpuDriverGIPA(VK_NULL_HANDLE, "vkEnumerateInstanceExtensionProperties"));
              ANGLE_VK_CHECK(context, mDualGpuEnumerateExtensions != nullptr, VK_ERROR_INCOMPATIBLE_DRIVER);
              ERR() << "DUALGPU: exclusive ICD vendor=" << preferredVendorId
                    << " device=" << preferredDeviceId << " interface=" << interfaceVersion;
          }
      #endif'''')
      # Only driver-provided global extensions, never loader-wide driver enumeration.
      replace(R,'    uint32_t instanceExtensionCount = 0;',''''    const PFN_vkEnumerateInstanceExtensionProperties enumerateExtensions =
              mDualGpuEnumerateExtensions ? mDualGpuEnumerateExtensions : vkEnumerateInstanceExtensionProperties;
          uint32_t instanceExtensionCount = 0;'''')
      p=root/R;s=p.read_text()
      s=s.replace('VK_CALL(vkEnumerateInstanceExtensionProperties, nullptr,','VK_CALL(enumerateExtensions, nullptr,')
      # In isolated mode explicit layers are unsupported: refuse instead of leaking to global discovery.
      s=s.replace('    for (const char *layerName : enabledInstanceLayerNames)\n', ''''    ANGLE_VK_CHECK(context, !mDualGpuDriverGIPA || enabledInstanceLayerNames.empty(),
                         VK_ERROR_LAYER_NOT_PRESENT);
          for (const char *layerName : enabledInstanceLayerNames)
      '''',1)
      p.write_text(s)
      replace(R,'    const std::string appName = angle::GetExecutableName();',''''    if (mDualGpuDriverGIPA)
              mEnabledInstanceExtensions.push_back(VK_LUNARG_DIRECT_DRIVER_LOADING_EXTENSION_NAME);

          const std::string appName = angle::GetExecutableName();'''')
      replace(R,'    instanceInfo.pApplicationInfo     = &mApplicationInfo;',''''    instanceInfo.pApplicationInfo     = &mApplicationInfo;
          VkDirectDriverLoadingInfoLUNARG directDriver = {};
          directDriver.sType = VK_STRUCTURE_TYPE_DIRECT_DRIVER_LOADING_INFO_LUNARG;
          directDriver.pfnGetInstanceProcAddr = mDualGpuDriverGIPA;
          VkDirectDriverLoadingListLUNARG directDrivers = {};
          directDrivers.sType = VK_STRUCTURE_TYPE_DIRECT_DRIVER_LOADING_LIST_LUNARG;
          directDrivers.mode = VK_DIRECT_DRIVER_LOADING_MODE_EXCLUSIVE_LUNARG;
          directDrivers.driverCount = 1;
          directDrivers.pDrivers = &directDriver;
          if (mDualGpuDriverGIPA)
              vk::AddToPNextChain(&instanceInfo, &directDrivers);'''')
      # Validate the selected device rather than silently accepting fallback selection.
      replace(R,'    // The device version that is assumed by ANGLE is the minimum of the actual device version and', ''''    if (mDualGpuDriverGIPA)
          {
              ANGLE_VK_CHECK(context, mPhysicalDeviceProperties.vendorID == preferredVendorId &&
                  (preferredDeviceId == 0 || mPhysicalDeviceProperties.deviceID == preferredDeviceId),
                  VK_ERROR_INCOMPATIBLE_DRIVER);
              ERR() << "DUALGPU: instance ready, physical device=" << mPhysicalDeviceProperties.deviceName;
          }

          // The device version that is assumed by ANGLE is the minimum of the actual device version and'''')
      replace(R,'    if (mLibVulkanLibrary)\n    {',''''    if (mDualGpuDriverLibrary)
          {
              // VkDevice and VkInstance have already been destroyed above.
              angle::CloseSystemLibrary(mDualGpuDriverLibrary);
              mDualGpuDriverLibrary = nullptr;
              mDualGpuDriverGIPA = nullptr;
              mDualGpuEnumerateExtensions = nullptr;
              ERR() << "DUALGPU: renderer and direct ICD reference released";
          }

          if (mLibVulkanLibrary)
          {'''')
      # Control both Chromium mappings for single-GPU comparisons in the same binary.
      prepend('gpu/ipc/service/gpu_init.cc','#include <cstdlib>\n#include <cstring>\n')
      replace('gpu/ipc/service/gpu_init.cc',''''  for (const auto& gpu : gpu_info.secondary_gpus) {
          classify_gpu(gpu);
        }
      #else'''',''''  for (const auto& gpu : gpu_info.secondary_gpus) {
          classify_gpu(gpu);
        }
        const char* mode = std::getenv("CHROMIUM_DUAL_GPU_MODE");
        if (mode && std::strcmp(mode, "intel") == 0) {
          gpu_high_perf = gpu_low_power;
        } else if (mode && std::strcmp(mode, "nvidia") == 0) {
          gpu_low_power = gpu_high_perf;
        }
      #else'''')
      # Private, read-only EGL query to gate teardown on all ANGLE-owned objects,
      # not just the count of WebGL command buffers. Never invalidate live resources.
      V=A+'src/libANGLE/validationEGL.cpp'
      replace(V,''''    ANGLE_VALIDATION_TRY(ValidateDisplay(val, display));

          switch (attribute)
          {
              case EGL_DEVICE_EXT:'''',''''    ANGLE_VALIDATION_TRY(ValidateDisplay(val, display));

          switch (attribute)
          {
              case 0x7FD0: // Private dual-GPU live-object bitmask.
                  break;
              case EGL_DEVICE_EXT:'''')
      D=A+'src/libANGLE/Display.cpp'
      replace(D,''''EGLAttrib Display::queryAttrib(const EGLint attribute)
      {
          EGLAttrib value = 0;'''',''''EGLAttrib Display::queryAttrib(const EGLint attribute)
      {
          if (attribute == 0x7FD0)
          {
              std::lock_guard<angle::SimpleMutex> lock(mState.contextMapMutex);
              return (!mState.contextMap.empty() || !mInvalidContextMap.empty() ? 1 : 0) |
                     (!mState.surfaceMap.empty() || !mInvalidSurfaceMap.empty() ? 2 : 0) |
                     (!mImageMap.empty() || !mInvalidImageMap.empty() ? 4 : 0) |
                     (!mSyncMap.empty() || !mInvalidSyncMap.empty() ? 8 : 0) |
                     (!mStreamSet.empty() || !mInvalidStreamSet.empty() ? 16 : 0);
          }
          EGLAttrib value = 0;'''')
      prepend('ui/gl/gl_display.h','#include "base/time/time.h"\n')
      replace('ui/gl/gl_display.h','    void Shutdown() override;' if False else '  void Shutdown() override;', ''''  void Shutdown() override;
        void TouchDualGpuDisplay();
        void TrimDualGpuDisplay();'''')
      replace('ui/gl/gl_display.h','\n  EGLDisplay display_ = EGL_NO_DISPLAY;',''''
        base::TimeTicks dual_gpu_idle_since_;
        EGLAttrib dual_gpu_last_busy_ = -1;
        EGLDisplay display_ = EGL_NO_DISPLAY;'''')
      # Insert before the unique global method, not nested observer members.
      prepend('ui/gl/gl_display.cc','#include <cstdlib>\n#include <cstring>\n')
      replace('ui/gl/gl_display.cc','void GLDisplayEGL::Shutdown() {',r''''void GLDisplayEGL::TouchDualGpuDisplay() {
        dual_gpu_idle_since_ = base::TimeTicks();
      }

      void GLDisplayEGL::TrimDualGpuDisplay() {
      #if BUILDFLAG(IS_LINUX)
        const char* trim = std::getenv("CHROMIUM_DUAL_GPU_TRIM");
        const char* mode = std::getenv("CHROMIUM_DUAL_GPU_MODE");
        if ((trim && std::strcmp(trim, "0") == 0) ||
            (mode && std::strcmp(mode, "nvidia") == 0) ||
            (system_device_id_ >> 32) != 0x10de || !IsInitialized() ||
            GetDisplayType() != ANGLE_VULKAN) {
          return;
        }
        EGLAttrib busy = -1;
        if (!eglQueryDisplayAttribEXT(display_, 0x7FD0, &busy)) {
          LOG(ERROR) << "DUALGPU: idle query failed; retaining NVIDIA display";
          return;
        }
        if (busy != dual_gpu_last_busy_) {
          LOG(ERROR) << "DUALGPU: NVIDIA live EGL object mask=" << busy
                     << " (1=context 2=surface 4=image 8=sync 16=stream)";
          dual_gpu_last_busy_ = busy;
        }
        if (busy != 0 || eglGetCurrentDisplay() == display_) {
          TouchDualGpuDisplay();
          return;
        }
        if (dual_gpu_idle_since_.is_null()) {
          dual_gpu_idle_since_ = base::TimeTicks::Now();
          return;
        }
        int seconds = 3;
        if (const char* value = std::getenv("CHROMIUM_DUAL_GPU_IDLE_SECONDS")) {
          int parsed = 0;
          if (base::StringToInt(value, &parsed) && parsed >= 1 && parsed <= 60)
            seconds = parsed;
        }
        if (base::TimeTicks::Now() - dual_gpu_idle_since_ < base::Seconds(seconds))
          return;
        LOG(ERROR) << "DUALGPU: terminating idle NVIDIA EGL display";
        Shutdown();
        TouchDualGpuDisplay();
      #endif
      }

      void GLDisplayEGL::Shutdown() {'''')
      # Retain GLDisplay object identity and mappings, so raw Chromium references stay
      # valid and the next high-power request can initialize the same display again.
      M='ui/gl/gl_display_manager.h'
      replace(M,'  bool IsEmpty() {',''''  void TrimDualGpuDisplays() {
          std::vector<GLDisplayPlatform*> snapshot;
          {
            base::AutoLock auto_lock(lock_);
            for (const auto& display : displays_)
              snapshot.push_back(display.get());
          }
          for (auto* display : snapshot)
            display->TrimDualGpuDisplay();
        }

        bool IsEmpty() {'''')
      # Export ui/gl-owned manager access; do not instantiate a second singleton in gpu.
      replace('ui/gl/gl_display.h','struct DisplayExtensionsEGL;',''''struct DisplayExtensionsEGL;
      GL_EXPORT void TrimDualGpuDisplays();'''')
      prepend('ui/gl/gl_display.cc','#include "ui/gl/gl_display_manager.h"\n')
      replace('ui/gl/gl_display.cc','namespace gl {',''''namespace gl {

      void TrimDualGpuDisplays() {
        GLDisplayManagerEGL::GetInstance()->TrimDualGpuDisplays();
      }
      '''')
      G='gpu/ipc/service/gpu_channel_manager.h'
      prepend(G,'#include "base/timer/timer.h"\n')
      replace(G,'  base::WeakPtrFactory<GpuChannelManager> weak_factory_{this};',''''  base::RepeatingTimer dual_gpu_trim_timer_;
        base::WeakPtrFactory<GpuChannelManager> weak_factory_{this};'''')
      G='gpu/ipc/service/gpu_channel_manager.cc'
      prepend(G,'#include "ui/gl/gl_display.h"\n')
      replace(G,''''  DCHECK(io_task_runner);
        DCHECK(scheduler);'''',''''  DCHECK(io_task_runner);
        DCHECK(scheduler);
      #if BUILDFLAG(IS_LINUX)
        dual_gpu_trim_timer_.Start(FROM_HERE, base::Seconds(1),
            base::BindRepeating(&gl::TrimDualGpuDisplays));
      #endif'''')
      replace('gpu/ipc/service/gles2_command_buffer_stub.cc',''''          /*gpu_preference=*/gpu_preference);

        // If the user queries'''',''''          /*gpu_preference=*/gpu_preference);
        if (!display)
          return gpu::ContextResult::kTransientFailure;
        if (auto* egl_display = display->GetAs<gl::GLDisplayEGL>())
          egl_display->TouchDualGpuDisplay();

        // If the user queries'''')
      print('Applied dispatch, driver-isolation, and safe idle-display teardown patches')

      replace(A+'src/common/vulkan/libvulkan_loader.cpp', '#if defined(ANGLE_USE_CUSTOM_LIBVULKAN)', '#if defined(ANGLE_USE_CUSTOM_LIBVULKAN) && !defined(ANGLE_PLATFORM_LINUX)')
      replace('ui/gl/gl_context_egl.cc', '  OnContextWillDestroy();\n  if (context_) {', ''''  OnContextWillDestroy();
      #if BUILDFLAG(IS_LINUX)
        if (context_ && (gl_display_->system_device_id() >> 32) == 0x10de &&
            eglGetCurrentContext() == context_) {
          ReleaseCurrent(nullptr);
        }
      #endif
        if (context_) {'''')
      replace(A+'src/third_party/volk/BUILD.gn', 'import("../../../gni/angle.gni")', ''''import("../../../gni/angle.gni")
      assert(angle_shared_libvulkan, "dual-GPU v6b requires the shared Vulkan loader")'''')
      replace('ui/gl/init/gl_factory.cc', ''''  if (!initialized) {
          DVLOG(1) << "Initialization failed. Attempting to initialize default "'''', ''''  if (!initialized) {
      #if BUILDFLAG(IS_LINUX)
          if (gpu_preference == gl::GpuPreference::kHighPerformance &&
              GetANGLEImplementation() == ANGLEImplementation::kVulkan &&
              features::SupportsEGLDualGPURendering()) {
            // Retain the preference mapping for a later retry (e.g. DTX reattach).
            // Do not silently satisfy an explicit high-power request with Intel.
            LOG(ERROR) << "DUALGPU: high-performance display initialization failed; mapping retained";
            return nullptr;
          }
      #endif
          DVLOG(1) << "Initialization failed. Attempting to initialize default "'''')
      replace('ui/gl/init/gl_factory.cc', ''''  if (!initialized) {
          ShutdownGL(display, false);'''', ''''  if (!initialized) {
      #if BUILDFLAG(IS_LINUX)
          if (gpu_preference == gl::GpuPreference::kHighPerformance && display &&
              GetANGLEImplementation() == ANGLEImplementation::kVulkan &&
              features::SupportsEGLDualGPURendering()) {
            display->Shutdown();
            return nullptr;
          }
      #endif
          ShutdownGL(display, false);'''')
      replace(R, '    bool loadLayers = (useDebugLayers != UseDebugLayers::No) || enableApiDumpLayer;', ''''    bool loadLayers = !mDualGpuDriverGIPA &&
                            ((useDebugLayers != UseDebugLayers::No) || enableApiDumpLayer);'''')
      replace(R, '    ANGLE_VK_TRY(context, VK_CALL(vkCreateDevice, mPhysicalDevice, &createInfo, nullptr, &mDevice));', ''''    ANGLE_VK_TRY(context, VK_CALL(vkCreateDevice, mPhysicalDevice, &createInfo, nullptr, &mDevice));
          ERR() << "DUALGPU: VkDevice ready vendor=" << mPhysicalDeviceProperties.vendorID
                << " device=" << mPhysicalDeviceProperties.deviceID;'''')
      replace('gpu/ipc/service/gles2_command_buffer_stub.cc', ''''  if (auto* egl_display = display->GetAs<gl::GLDisplayEGL>())
          egl_display->TouchDualGpuDisplay();'''', ''''  if (auto* egl_display = display->GetAs<gl::GLDisplayEGL>()) {
          egl_display->TouchDualGpuDisplay();
          LOG(ERROR) << "DUALGPU: WebGL preference=" << static_cast<int>(gpu_preference)
                     << " display vendor/device=" << egl_display->system_device_id();
        }'''')
      replace('gpu/ipc/service/gpu_init.cc', ''''#if BUILDFLAG(USE_WEBGPU_ON_VULKAN_VIA_GL_INTEROP)
      #if BUILDFLAG(IS_OZONE)'''', ''''#if BUILDFLAG(IS_LINUX)
        const char* dual_gpu_isolation = std::getenv("CHROMIUM_DUAL_GPU_ISOLATION");
        if (!dual_gpu_isolation || std::strcmp(dual_gpu_isolation, "0") != 0) {
          // This prototype isolates ANGLE WebGL instances. Independent compositor /
          // WebGPU Vulkan instances would reintroduce loader-wide driver discovery.
          gpu_feature_info_.status_values[GPU_FEATURE_TYPE_VULKAN] = kGpuFeatureStatusDisabled;
          gpu_feature_info_.status_values[GPU_FEATURE_TYPE_WEBGPU_ON_VK_VIA_GL_INTEROP] =
              kGpuFeatureStatusDisabled;
        }
      #endif
      #if BUILDFLAG(USE_WEBGPU_ON_VULKAN_VIA_GL_INTEROP)
      #if BUILDFLAG(IS_OZONE)'''')


      from pathlib import Path
      root=Path('.')
      p=root/'content/common/gpu_pre_sandbox_hook_linux.cc'
      s=p.read_text()
      def replace(old,new):
       global s
       if s.count(old)!=1:raise RuntimeError(f'sandbox: expected one match {old[:80]!r}, got {s.count(old)}')
       s=s.replace(old,new,1)
      replace('#include <dlfcn.h>','#include <dlfcn.h>\n#include <link.h>\n#include <set>\n#include <cstring>\n#include "base/compiler_specific.h"\n#include "base/files/file_util.h"')
      replace('void LoadVulkanLibraries() {',r''''// Use the runtime linker's effective search paths. Reading this metadata and
      // resolving file symlinks does not load or initialize the NVIDIA ICD. Permit
      // lazy driver/dependency opens through the existing read-only file broker.
      void AddDualGpuDriverLibraryPermissions(std::vector<BrokerFilePermission>* permissions) {
        std::set<std::string> directories;
        dl_iterate_phdr([](dl_phdr_info* info, size_t, void* opaque) {
          auto* dirs = static_cast<std::set<std::string>*>(opaque);
          void* module = info->dlpi_name && info->dlpi_name[0]
              ? dlopen(info->dlpi_name, RTLD_LAZY | RTLD_NOLOAD)
              : dlopen(nullptr, RTLD_LAZY);
          if (!module)
            return 0;
          Dl_serinfo size{};
          if (dlinfo(module, RTLD_DI_SERINFOSIZE, &size) == 0 &&
              size.dls_size >= sizeof(Dl_serinfo)) {
            std::vector<char> storage(size.dls_size);
            auto* paths = reinterpret_cast<Dl_serinfo*>(storage.data());
            if (dlinfo(module, RTLD_DI_SERINFOSIZE, paths) == 0 &&
                dlinfo(module, RTLD_DI_SERINFO, paths) == 0) {
              for (unsigned int i = 0; i < paths->dls_cnt; ++i) {
                const char* path = UNSAFE_TODO(paths->dls_serpath[i].dls_name);
                if (path && path[0] == '/' && std::strlen(path) > 1)
                  dirs->insert(path);
              }
            }
          }
          dlclose(module);
          return 0;
        }, &directories);
        void* loader = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL);
        using ResolveDriver = const char* (*)(uint32_t);
        auto resolve = loader ? reinterpret_cast<ResolveDriver>(
            dlsym(loader, "vkDualGpuDriverPathCHROMIUM_v1")) : nullptr;
        if (resolve) {
          for (uint32_t vendor : {0x8086u, 0x10deu}) {
            if (const char* path = resolve(vendor)) {
              directories.insert(base::FilePath(path).DirName().value());
              LOG(ERROR) << "DUALGPU: metadata-only driver discovery vendor=" << vendor;
            }
          }
        } else {
          LOG(ERROR) << "DUALGPU: required metadata resolver missing before sandbox";
        }
        // Pin only the loader: its metadata cache must survive sandbox entry.
        for (const auto& directory : directories) {
          if (directory == "/")
            continue;
          permissions->push_back(BrokerFilePermission::ReadOnlyRecursive(
              base::FilePath(directory).AsEndingWithSeparator().value()));
        }
        permissions->push_back(BrokerFilePermission::ReadOnly("/etc/ld.so.cache"));
        permissions->push_back(BrokerFilePermission::ReadWrite("/dev/nvidia-uvm"));
        permissions->push_back(BrokerFilePermission::ReadWrite("/dev/nvidia-uvm-tools"));
        permissions->push_back(BrokerFilePermission::ReadOnlyRecursive("/proc/driver/nvidia/"));
      }

      void LoadVulkanLibraries() {
        const char* isolation = getenv("CHROMIUM_DUAL_GPU_ISOLATION");
        if (!isolation || std::strcmp(isolation, "0") != 0) {
          // Keep the loader available; ANGLE owns unloadable vendor references.
          dlopen("libvulkan.so.1", dlopen_flag);
          return;
        }'''')
      replace(''''  AddStandardGpuPermissions(&permissions);
        return permissions;'''',''''  AddStandardGpuPermissions(&permissions);
        AddDrmGpuPermissions(&permissions);
        AddDualGpuDriverLibraryPermissions(&permissions);
        return permissions;'''')
      p.write_text(s)
      print('Applied runtime-linker broker permissions and removed vendor NODELETE preloads')
      PY
    '';
  });

  # Nixpkgs' Chromium wrapper closes over its private chromium.browser
  # derivation, so overriding passthru.browser alone does not replace the
  # browser executable.  Reuse the normal wrapper derivation but replace the
  # exact unwrapped browser/sandbox store paths in its generated buildCommand.
  patchedRuntime = baseChromium.overrideAttrs (old: {
    pname = "chromium-dual-gpu-prototype-v6b-runtime";

    buildCommand = builtins.replaceStrings
      [
        "${originalBrowser}"
        "${originalBrowser.sandbox}"
      ]
      [
        "${patchedBrowser}"
        "${patchedBrowser.sandbox}"
      ]
      old.buildCommand;

    passthru = (old.passthru or { }) // {
      browser = patchedBrowser;
    };
  });

  launcher = pkgs.writeShellScriptBin "chromium-dual-gpu" ''
    set -e

    profile_root="''${XDG_CONFIG_HOME:-$HOME/.config}"
    profile="$profile_root/chromium-dual-gpu-prototype-v6b"

    case "''${CHROMIUM_DUAL_GPU_MODE:-dual}" in
      dual|intel|nvidia) ;;
      *) echo "CHROMIUM_DUAL_GPU_MODE must be dual, intel or nvidia" >&2; exit 2 ;;
    esac
    unset VK_DRIVER_FILES VK_ICD_FILENAMES VK_ADD_DRIVER_FILES VK_INSTANCE_LAYERS
    unset __NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME __VK_LAYER_NV_optimus
    unset LIBVA_DRIVER_NAME
    export VK_LOADER_LAYERS_DISABLE="~implicit~"
    export LD_LIBRARY_PATH="${lib.getLib dualGpuLoader}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    exec ${patchedRuntime}/bin/chromium \
      --user-data-dir="$profile" \
      "$@"
  '';

  testPage = pkgs.writeText "chromium-dual-gpu-test-v6b.html" ''
    <!doctype html><meta charset="utf-8"><title>Dual GPU v6b</title>
    <style>body{font:16px system-ui;margin:2em;max-width:1000px}button{margin:.3em;padding:.6em}iframe{width:440px;height:230px;border:1px solid #888}pre{white-space:pre-wrap}</style>
    <h1>Dual GPU v6b</h1><p>Default and low-power contexts start immediately. Add NVIDIA contexts explicitly. Removing their iframes destroys the documents that own them.</p>
    <button id="add">Add high-performance context</button><button id="remove">Remove all high contexts</button>
    <button id="cycle">Run 10 create/remove cycles</button><button id="stop">Stop cycling and remove high contexts</button>
    <p id="count"></p><div id="frames"></div><pre id="log"></pre>
    <script>
    let high=[],serial=0,cycling=false;
    const frames=document.getElementById('frames'),log=document.getElementById('log');
    function record(s){log.textContent+=new Date().toISOString()+' '+s+'\n';}
    window.addEventListener('message',e=>{if(e.source && [...frames.children].some(f=>f.contentWindow===e.source))record(String(e.data));});
    function create(preference){
     const frame=document.createElement('iframe'),name=preference+' #'+(++serial);
     frame.srcdoc='<!doctype html><style>body{font:14px system-ui}canvas{width:400px;height:150px}</style><b>'+name+'</b><br><canvas width="400" height="150"></canvas><script>const name='+JSON.stringify(name)+',preference='+JSON.stringify(preference)+';'+String.raw`
     const c=document.querySelector('canvas');
     const gl=c.getContext('webgl2',preference==='default'?{}:{powerPreference:preference});
     const report=s=>parent.postMessage(name+': '+s,'*');
     c.addEventListener('webglcontextlost',e=>{e.preventDefault();report('CONTEXT LOST');});
     c.addEventListener('webglcontextrestored',()=>report('CONTEXT RESTORED'));
     if(!gl)report('CREATE FAILED');else{
     const ext=gl.getExtension('WEBGL_debug_renderer_info');report(ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER));
     const program=gl.createProgram();
     for(const [kind,text] of [[gl.VERTEX_SHADER,'#version 300 es\nvoid main(){vec2 p[3]=vec2[3](vec2(-.8,-.8),vec2(.8,-.8),vec2(0,.8));gl_Position=vec4(p[gl_VertexID],0,1);}'],[gl.FRAGMENT_SHADER,'#version 300 es\nprecision highp float;uniform float t;out vec4 color;void main(){color=vec4(.5+.5*sin(t),.6,.9,1.);}']]){
     const shader=gl.createShader(kind);gl.shaderSource(shader,text);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS))report(gl.getShaderInfoLog(shader));gl.attachShader(program,shader);gl.deleteShader(shader);}
     gl.linkProgram(program);gl.useProgram(program);const t=gl.getUniformLocation(program,'t');let previous=0;
     function draw(now){if(gl.isContextLost())return;gl.clearColor(.08,.1,.15,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.uniform1f(t,now/1000);gl.drawArrays(gl.TRIANGLES,0,3);if(now-previous>5000){previous=now;const p=new Uint8Array(4);gl.readPixels(200,75,1,1,gl.RGBA,gl.UNSIGNED_BYTE,p);const err=gl.getError();if(err)report('GL error '+err);if(p[3]!==255)report('READBACK alpha mismatch '+p);}requestAnimationFrame(draw);}requestAnimationFrame(draw);
     }
     `+'<\/script>';
     frames.append(frame);return frame;
    }
    function update(){document.getElementById('count').textContent='Live high-performance documents: '+high.length;}
    function add(){high.push(create('high-performance'));update();}
    function remove(){for(const f of high)f.remove();high=[];update();record('High documents removed; allow 10 seconds for GPU cleanup.');}
    create('default');create('low-power');update();
    document.getElementById('add').onclick=add;document.getElementById('remove').onclick=remove;
    document.getElementById('stop').onclick=()=>{cycling=false;remove();};
    const delay=ms=>new Promise(r=>setTimeout(r,ms));
    document.getElementById('cycle').onclick=async()=>{if(cycling)return;cycling=true;for(let i=0;i<10&&cycling;i++){record('Cycle '+(i+1));add();await delay(5000);remove();await delay(10000);}cycling=false;record('Cycles finished');};
    </script>
  '';

  testLauncher = pkgs.writeShellScriptBin "chromium-dual-gpu-test" ''
    exec ${launcher}/bin/chromium-dual-gpu "file://${testPage}" "$@"
  '';

  stateSource = pkgs.writeText "chromium-dual-gpu-state.py" ''
    import os
    from pathlib import Path
    uid=int(os.environ.get('SUDO_UID',os.getuid()))
    vendors={}
    for d in sorted(Path('/sys/class/drm').glob('*')):
        try: vendors['/dev/dri/'+d.name]=(d/'device/vendor').read_text().strip()
        except OSError: pass
    for d in sorted(Path('/sys/bus/pci/devices').glob('*')):
        try:
            vendor=(d/'vendor').read_text().strip()
            if vendor not in ('0x8086','0x10de'): continue
            if not (d/'class').read_text().strip().startswith('0x03'): continue
            fields=[]
            for name in ('runtime_status','control','runtime_suspended_time'):
                try: fields.append(name+'='+(d/'power'/name).read_text().strip())
                except OSError: pass
            print(d.name,vendor,' '.join(fields))
        except OSError: pass
    count=unknown=processes=0
    # Include all Chromium-family processes owned by this user, including brokers.
    # Other browser instances are deliberately included to avoid a false zero.
    for p in sorted(Path('/proc').glob('[0-9]*'),key=lambda x:int(x.name)):
        try:
            if p.stat().st_uid!=uid: continue
            cmd=(p/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')
            exe=os.readlink(p/'exe')
            if not any(x in Path(exe).name.lower() for x in ('chromium','chrome')): continue
            processes+=1
            kind=next((x for x in cmd.split() if x.startswith('--type=')),'browser/launcher')
            print('PID',p.name,kind)
            try: fds=list((p/'fd').iterdir())
            except PermissionError: unknown+=1;print('  FD ACCESS DENIED: zero cannot be established');continue
            for fd in fds:
                try: target=os.readlink(fd)
                except FileNotFoundError: continue
                except PermissionError: unknown+=1;continue
                if target.startswith('/dev/nvidia') or target.startswith('/dev/dri/'):
                    vendor=vendors.get(target,'unknown')
                    nv=target.startswith('/dev/nvidia') or vendor=='0x10de'
                    count+=int(nv)
                    print('  fd='+fd.name,target,'vendor='+vendor, 'NVIDIA' if nv else ''')
        except (FileNotFoundError,ProcessLookupError): continue
        except PermissionError: unknown+=1
    print('Chromium-family processes:',processes,'NVIDIA device FDs:',count,'unreadable entries:',unknown)
    if not processes: print('No browser process found; this is not an idle-browser pass.')
    if unknown: print('INCOMPLETE visibility; do not interpret this as proof of zero NVIDIA handles.')
  '';
  stateTool = pkgs.writeShellScriptBin "chromium-dual-gpu-state" ''
    exec ${pkgs.python3}/bin/python3 ${stateSource} "$@"
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "chromium-dual-gpu";
    desktopName = "Chromium (Dual GPU Prototype v6b)";
    genericName = "Web Browser";
    comment = "Experimental per-WebGL-context Intel/NVIDIA GPU selection";
    exec = "chromium-dual-gpu %U";
    icon = "${patchedBrowser}/share/icons/hicolor/256x256/apps/chromium.png";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeTypes = [
      "text/html"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };

  package = pkgs.symlinkJoin {
    name = "chromium-dual-gpu-prototype-v6b";
    paths = [
      launcher
      testLauncher
      stateTool
      preflight
      desktopItem
    ];
  };

in
{
  options.programs.chromiumDualGpuPrototype = {
    enable = lib.mkEnableOption ''
      experimental Chromium build that keeps default WebGL on Intel and routes
      explicit high-performance WebGL contexts through ANGLE/Vulkan to NVIDIA
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      defaultText = lib.literalExpression "pkgs.chromium";
      description = ''
        Nixpkgs Chromium wrapper to patch.  It must expose the standard
        `browser` passthru used by pkgs.chromium.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--enable-logging=stderr" ];
      description = "Additional command-line arguments for the prototype Chromium.";
    };

    preflightPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Small loader/isolation/lifecycle test; does not build Chromium.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "The resulting Chromium dual-GPU prototype launcher package.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.chromiumDualGpuPrototype.finalPackage = package;
    programs.chromiumDualGpuPrototype.preflightPackage = preflight;

    home.packages = [ package ];
  };
}
