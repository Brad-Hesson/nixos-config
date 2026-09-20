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
    postPatch = (old.postPatch or "") + ''
      echo "Applying Chromium Linux dual-GPU WebGL prototype v5 patch"

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
      # v3 proved the multi-GPU path works, but its blanket removal of kGL from
      # every HIGH_PERFORMANCE_GPU backing is too coarse for real applications
      # like Onshape.  M153 already has DCSI's AccessParams/SupportsAccess
      # infrastructure; extend it with the actual GL share-group identity so a
      # GLTextureImageBacking is reused only by a compatible GL context.
      #
      # This follows Chromium's own GLContext compatibility model:
      # contexts in the same GLShareGroup can reuse textures; Intel and NVIDIA
      # ANGLE displays necessarily have different share groups.

      # 4a. Extend AccessParams with the requesting GL share group.
      replace_once(
          "gpu/command_buffer/service/shared_image/shared_image_backing.h",
          """namespace gfx {
      class D3DSharedFence;
      class GpuFence;
      }  // namespace gfx
      namespace gpu {
      """,
          """namespace gfx {
      class D3DSharedFence;
      class GpuFence;
      }  // namespace gfx
      namespace gl {
      class GLShareGroup;
      }  // namespace gl
      namespace gpu {
      """,
          "forward-declare GLShareGroup for SharedImage AccessParams",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/shared_image_backing.h",
          """  scoped_refptr<SharedContextState> context_state = nullptr;
        wgpu::Device wgpu_device = nullptr;
        // Other context types can be added here in the future.
      """,
          """  scoped_refptr<SharedContextState> context_state = nullptr;
        wgpu::Device wgpu_device = nullptr;
        // GL accesses do not currently carry a SharedContextState. Keep the
        // actual GL share-group identity so CompoundImageBacking can distinguish
        // Intel and NVIDIA GL/ANGLE contexts.
        raw_ptr<gl::GLShareGroup> gl_share_group = nullptr;
        // Other context types can be added here in the future.
      """,
          "add GL share-group identity to SharedImage AccessParams",
      )

      # 4b. Store the GL share group that actually created each GL texture
      # backing. Dynamic allocations occur while the requesting GL context is
      # current, so a newly-created NVIDIA backing records the NVIDIA group.
      replace_once(
          "gpu/command_buffer/service/shared_image/gl_texture_image_backing.h",
          """#include "gpu/command_buffer/service/shared_image/gl_texture_holder.h"

      class GrPromiseImageTexture;
      """,
          """#include "gpu/command_buffer/service/shared_image/gl_texture_holder.h"
      #include "ui/gl/gl_share_group.h"

      class GrPromiseImageTexture;
      """,
          "include GLShareGroup for GLTextureImageBacking ownership",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/gl_texture_image_backing.h",
          """  const bool is_passthrough_;

        std::vector<scoped_refptr<GLTextureHolder>> textures_;
      """,
          """  const bool is_passthrough_;
        scoped_refptr<gl::GLShareGroup> share_group_;

        std::vector<scoped_refptr<GLTextureHolder>> textures_;
      """,
          "store creating GL share group on GLTextureImageBacking",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/gl_texture_image_backing.cc",
          """      is_passthrough_(is_passthrough) {
      """,
          """      is_passthrough_(is_passthrough),
            share_group_(gl::GLContext::GetCurrent()
                             ? gl::GLContext::GetCurrent()->share_group()
                             : nullptr) {
      """,
          "capture current GL share group when creating GL texture backing",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/gl_texture_image_backing.cc",
          """bool GLTextureImageBacking::SupportsAccess(SharedImageAccessStream stream,
                                                 const AccessParams& params) const {
        return CheckSupportForAccessStream(stream, params);
      }
      """,
          """bool GLTextureImageBacking::SupportsAccess(SharedImageAccessStream stream,
                                                 const AccessParams& params) const {
        if (!CheckSupportForAccessStream(stream, params)) {
          return false;
        }

        // If the caller supplied an explicit GL share group, require this
        // backing's texture storage to be shareable with that group.
        if (params.gl_share_group && share_group_ &&
            params.gl_share_group != share_group_.get()) {
          return false;
        }

        // Skia/Ganesh callers already carry SharedContextState. Apply the same
        // share-group check there as well.
        if (params.context_state && params.context_state->GrContextIsGL() &&
            share_group_ &&
            params.context_state->share_group() != share_group_.get()) {
          return false;
        }

        return true;
      }
      """,
          "make GLTextureImageBacking access share-group aware",
      )

      # 4c. CompoundImageBacking currently passes empty AccessParams for GL,
      # despite an explicit source comment saying GL context information may be
      # needed when one backing is used from another context. Pass the current
      # GL share group for both legacy and passthrough GL representations.
      replace_once(
          "gpu/command_buffer/service/shared_image/compound_image_backing.cc",
          """#include "ui/gfx/gpu_memory_buffer_handle.h"
      """,
          """#include "ui/gfx/gpu_memory_buffer_handle.h"
      #include "ui/gl/gl_context.h"
      """,
          "include GLContext for current share-group lookup",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/compound_image_backing.cc",
          """std::unique_ptr<GLTextureImageRepresentation>
      CompoundImageBacking::ProduceGLTexture(SharedImageManager* manager,
                                             MemoryTypeTracker* tracker) {
        // For GLTextureImageRepresentation, the SharedImageAccessStream::kGL is
        // specific enough for backing selection. While AccessParams could be extended
        // in the future to include GL context information for stricter correctness
        // checks (e.g., ensuring a backing created on one GL context isn't used on
        // another, unless it's an EglImageBacking), it is not currently needed.
        std::unique_ptr<SharedImageBacking> transient_backing;
        auto* backing = GetOrAllocateBacking(SharedImageAccessStream::kGL,
                                             AccessParams(), transient_backing);
      """,
          """std::unique_ptr<GLTextureImageRepresentation>
      CompoundImageBacking::ProduceGLTexture(SharedImageManager* manager,
                                             MemoryTypeTracker* tracker) {
        AccessParams access_params;
        if (auto* current_context = gl::GLContext::GetCurrent()) {
          access_params.gl_share_group = current_context->share_group();
        }
        std::unique_ptr<SharedImageBacking> transient_backing;
        auto* backing = GetOrAllocateBacking(SharedImageAccessStream::kGL,
                                             access_params, transient_backing);
      """,
          "make GLTexture compound-backing selection context aware",
      )

      replace_once(
          "gpu/command_buffer/service/shared_image/compound_image_backing.cc",
          """std::unique_ptr<GLTexturePassthroughImageRepresentation>
      CompoundImageBacking::ProduceGLTexturePassthrough(SharedImageManager* manager,
                                                        MemoryTypeTracker* tracker) {
        // For GLTexturePassthroughImageRepresentation, the
        // SharedImageAccessStream::kGL is specific enough for backing selection.
        // While AccessParams could be extended in the future to include GL context
        // information for stricter correctness checks, it is not currently needed.
        std::unique_ptr<SharedImageBacking> transient_backing;
        auto* backing = GetOrAllocateBacking(SharedImageAccessStream::kGL,
                                             AccessParams(), transient_backing);
      """,
          """std::unique_ptr<GLTexturePassthroughImageRepresentation>
      CompoundImageBacking::ProduceGLTexturePassthrough(SharedImageManager* manager,
                                                        MemoryTypeTracker* tracker) {
        AccessParams access_params;
        if (auto* current_context = gl::GLContext::GetCurrent()) {
          access_params.gl_share_group = current_context->share_group();
        }
        std::unique_ptr<SharedImageBacking> transient_backing;
        auto* backing = GetOrAllocateBacking(SharedImageAccessStream::kGL,
                                             access_params, transient_backing);
      """,
          "make passthrough GL compound-backing selection context aware",
      )

      # 5. Backport Chromium upstream commit f1ca08ec7e806878ea916776bc3114b438333efe
      # (2026-09-17). This is directly relevant once there can be multiple GPU
      # elements: readback must select the element holding latest_content_id_,
      # not merely the first non-memory element.
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
          "backport latest-content synchronous readback fix",
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
          "backport latest-content asynchronous readback null guard",
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
          "backport latest-content GPU backing selection fix",
      )

      print("dual-gpu patch v5: all prototype edits applied successfully")
      PY
    '';
  });

  # Nixpkgs' Chromium wrapper closes over its private chromium.browser
  # derivation, so overriding passthru.browser alone does not replace the
  # browser executable.  Reuse the normal wrapper derivation but replace the
  # exact unwrapped browser/sandbox store paths in its generated buildCommand.
  patchedRuntime = baseChromium.overrideAttrs (old: {
    pname = "chromium-dual-gpu-prototype-v5-runtime";

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
    profile="$profile_root/chromium-dual-gpu-prototype-v5"

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
    desktopName = "Chromium (Dual GPU Prototype v5)";
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
    name = "chromium-dual-gpu-prototype-v5";
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
