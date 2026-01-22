# STM32 Build Workflow Examples

This directory contains example workflows for building STM32 firmware using the `stm32-build` reusable workflow.

## Available Examples

| Example | Description | Use Case |
|---------|-------------|----------|
| [basic-makefile.yml](basic-makefile.yml) | Simple Makefile build | STM32CubeMX generated projects |
| [cmake-project.yml](cmake-project.yml) | CMake-based build | Complex projects with CMake |
| [multi-mcu-matrix.yml](multi-mcu-matrix.yml) | Matrix build for multiple MCUs | Products supporting multiple STM32 variants |
| [industrial-release.yml](industrial-release.yml) | Secure release pipeline | Safety-critical applications |

## Quick Start

### 1. Basic Makefile Build

For STM32CubeMX generated projects:

```yaml
name: STM32 Build

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/stm32-build.yml@main
    with:
      build-system: makefile
      target-mcu: STM32F407VG
```

### 2. CMake Build

For CMake-based projects:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/stm32-build.yml@main
    with:
      build-system: cmake
      target-mcu: STM32H743ZI
      cmake-toolchain: cmake/arm-none-eabi.cmake
```

### 3. Production Release

For tagged releases:

```yaml
jobs:
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: bauer-group/automation-templates/.github/workflows/stm32-build.yml@main
    with:
      config-file: industrial
      create-release: true
```

## Configuration Templates

| Template | Description |
|----------|-------------|
| `default` | Standard projects, basic settings |
| `industrial` | Safety-critical with MISRA checks |
| `prototype` | Fast iteration, debug builds |
| `low-power` | Optimized for battery devices |

## Supported STM32 Families

| Family | Core | Typical Use |
|--------|------|-------------|
| STM32F0 | Cortex-M0 | Entry-level |
| STM32F1 | Cortex-M3 | Mainstream |
| STM32F4 | Cortex-M4F | High-performance |
| STM32F7 | Cortex-M7 | High-performance |
| STM32G0 | Cortex-M0+ | Cost-optimized |
| STM32G4 | Cortex-M4F | Motor control |
| STM32H7 | Cortex-M7 | Highest performance |
| STM32L0/L4 | Cortex-M0+/M4 | Ultra-low-power |
| STM32WB/WL | Cortex-M4/M0+ | Wireless |

## Project Structure

### Makefile Project (STM32CubeMX)

```
my-stm32-project/
├── .github/
│   └── workflows/
│       └── build.yml
├── Core/
│   ├── Inc/
│   └── Src/
│       └── main.c
├── Drivers/
│   ├── CMSIS/
│   └── STM32F4xx_HAL_Driver/
├── Makefile
├── STM32F407VGTx_FLASH.ld
└── startup_stm32f407vgtx.s
```

### CMake Project

```
my-stm32-project/
├── .github/
│   └── workflows/
│       └── build.yml
├── cmake/
│   └── arm-none-eabi.cmake
├── src/
│   └── main.c
├── include/
├── CMakeLists.txt
└── STM32F407VGTx_FLASH.ld
```

## Toolchain Versions

The workflow uses the [xPack ARM GCC](https://xpack.github.io/arm-none-eabi-gcc/) toolchain.

**Available versions:**
- `13.3.rel1` - Latest (recommended)
- `12.3.rel1` - Previous stable
- `11.3.rel1` - Older stable

## Troubleshooting

### "arm-none-eabi-gcc not found"

The toolchain is installed automatically. Check runner logs for installation errors.

### "Makefile not found"

Ensure your `project-path` points to the directory containing the Makefile.

### "Linker script not found"

Check that your `.ld` file is referenced correctly in the Makefile or CMake.

### Size analysis shows unexpected values

Verify the ELF file is being generated and the path is correct.

## Resources

- [STM32CubeMX](https://www.st.com/en/development-tools/stm32cubemx.html)
- [ARM GNU Toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
- [STMicroelectronics GitHub](https://github.com/STMicroelectronics)
- [GitHub Actions for STM32CubeIDE](https://interrupt.memfault.com/blog/github-actions-for-stm32cubeide)
