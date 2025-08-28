# SPI Loopback

The example demonstrates how to utilize lib_fast_spi on XK-VOICE-L71.

SPI master and slave will each occupy one logical core on tile0.

The program will keep try with different SPI speed, different reg addr, different transfer length.

The program will output error message and stop testing when it found the transfer data is not correct. 

## Get Started

1. Configure Project through CMake
    ```console
    # if using Windows
    cmake -G Ninja -B build
    # else
    cmake -B build
    ```

2. Build the firmware
    ```console
    # if using Windows
    ninja -C build
    # else
    xmake -C build
    ```

## Hardware Configuration
Connect the following XK-VOICE-L71 pins in pair
| Function | Master Pin | Slave Pin |
|---|---|---|
| SCK | J6 (SPI CLK) | J8 (CS_N) |
| MISO | J6 (MISO) | J6 (SDA) |
| MOSI | J6 (MOSI) | J6 (SCL) |
| CS/SS | J8 (D0) | J6 (SPI_CS_N) |