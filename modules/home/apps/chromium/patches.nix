{ config, lib, pkgs, ... }:

# Home Manager module

let
  cfg = config.programs.chromiumDualGpuPrototype;

  # Keep this deliberately separate from the user's normal Chromium.
  # These flags force WebGL through ANGLE/Vulkan so ANGLE can explicitly
  # choose a VkPhysicalDevice.
  chromiumArgs = [
    "--use-gl=angle"
    "--use-angle=vulkan"
    "--ozone-platform=wayland"
    "--enable-features=EGLDualGPURendering,WaylandWindowDecorations,UseDynamicBackingAllocations"
    "--enable-wayland-ime=true"
  ] ++ cfg.extraArgs;

  baseChromium = cfg.package.override {
    commandLineArgs = lib.escapeShellArgs chromiumArgs;
  };

  originalBrowser = baseChromium.browser;

  patchedBrowser = originalBrowser.overrideAttrs (old: {
    NIXBUILDNET_MIN_CPU = "16";
    NIXBUILDNET_MAX_CPU = "32";
    postPatch = (old.postPatch or "") + ''
      echo "Applying Chromium Linux dual-GPU WebGL prototype v4.1 patch"

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
      PY
    '';
  });

  # Nixpkgs' Chromium wrapper closes over its private chromium.browser
  # derivation, so overriding passthru.browser alone does not replace the
  # browser executable.  Reuse the normal wrapper derivation but replace the
  # exact unwrapped browser/sandbox store paths in its generated buildCommand.
  patchedRuntime = baseChromium.overrideAttrs (old: {
    pname = "chromium-dual-gpu-prototype-v4_1-runtime";

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
    profile="$profile_root/chromium-dual-gpu-prototype-v4_1"

    exec ${patchedRuntime}/bin/chromium \
      --user-data-dir="$profile" \
      "$@"
  '';

  testPage = pkgs.writeText "chromium-dual-gpu-test.html" ''
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Chromium dual-GPU WebGL test</title>
      <style>
        body {
          font: 16px system-ui, sans-serif;
          max-width: 900px;
          margin: 3rem auto;
          padding: 0 1rem;
        }
        pre {
          padding: 1rem;
          border: 1px solid;
          white-space: pre-wrap;
        }
        canvas {
          width: 300px;
          height: 120px;
          border: 1px solid;
          margin: 0.5rem;
        }
      </style>
    </head>
    <body>
      <h1>Chromium dual-GPU WebGL prototype</h1>
      <p>
        The first context requests <code>low-power</code>; the second requests
        <code>high-performance</code>.  On the intended setup the renderer
        strings should identify Intel and NVIDIA respectively.
      </p>
      <pre id="out"></pre>
      <div id="canvases"></div>

      <script>
        const out = document.getElementById("out");
        const keepAlive = [];

        function inspect(label, preference) {
          const canvas = document.createElement("canvas");
          document.getElementById("canvases").appendChild(canvas);

          const gl = canvas.getContext("webgl2", {
            powerPreference: preference,
            antialias: true
          });

          if (!gl) {
            return label + ": WebGL2 context creation FAILED";
          }

          keepAlive.push(gl);

          const ext = gl.getExtension("WEBGL_debug_renderer_info");
          const vendor = ext
            ? gl.getParameter(ext.UNMASKED_VENDOR_WEBGL)
            : gl.getParameter(gl.VENDOR);
          const renderer = ext
            ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)
            : gl.getParameter(gl.RENDERER);

          gl.clearColor(
            preference === "high-performance" ? 0.15 : 0.45,
            0.3,
            preference === "high-performance" ? 0.55 : 0.15,
            1.0
          );
          gl.clear(gl.COLOR_BUFFER_BIT);

          return label + "\n  vendor:   " + vendor + "\n  renderer: " + renderer;
        }

        const results = [
          inspect("low-power", "low-power"),
          inspect("high-performance", "high-performance")
        ];

        out.textContent = results.join("\n\n");
      </script>
    </body>
    </html>
  '';

  testLauncher = pkgs.writeShellScriptBin "chromium-dual-gpu-test" ''
    exec ${launcher}/bin/chromium-dual-gpu "file://${testPage}"
  '';

  stateTool = pkgs.writeShellScriptBin "chromium-dual-gpu-state" ''
    found=0

    for d in /sys/bus/pci/devices/*; do
      [ -r "$d/vendor" ] || continue
      [ "$(cat "$d/vendor")" = "0x10de" ] || continue

      found=1
      echo "NVIDIA PCI device: ''${d##*/}"

      if [ -r "$d/power/runtime_status" ]; then
        echo "  runtime_status: $(cat "$d/power/runtime_status")"
      fi

      if [ -r "$d/power/runtime_suspended_time" ]; then
        echo "  runtime_suspended_time: $(cat "$d/power/runtime_suspended_time") ms"
      fi

      if [ -r "$d/power/control" ]; then
        echo "  power/control: $(cat "$d/power/control")"
      fi
    done

    if [ "$found" -eq 0 ]; then
      echo "No NVIDIA PCI device is currently present."
    fi
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "chromium-dual-gpu";
    desktopName = "Chromium (Dual GPU Prototype v4.1)";
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
    name = "chromium-dual-gpu-prototype-v4_1";
    paths = [
      launcher
      testLauncher
      stateTool
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

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "The resulting Chromium dual-GPU prototype launcher package.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.chromiumDualGpuPrototype.finalPackage = package;

    home.packages = [ package ];
  };
}
