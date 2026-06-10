# Printimate Hardware

This folder contains the hardware design files for the physical printer.

* `schematic.png`: Electrical schematic for the project. Note that the status LED was planned and implemented in software, but did not make it into our prototype printer due to sourcing constraints.
* `box`: Directory containing 3D design files for the printer box. These were designed using Autodesk Fusion 360.

## Hardware Design
The printimate printer is designed around an ESP32 microcontroller, specifically the [ESP32-WROOM-32](https://www.amazon.com/dp/B0CR5Y2JVD?ref_=ppx_hzsearch_conn_dt_b_fed_asin_title_6&th=1) board. This was chosen for several reasons:
* The board has integrated Wi-Fi and Bluetooth support
* This board is cheap (~$5 per unit)
* This board comes with exposed header pins, making manual soldering easy

For the actual printing, we use an off-the-shelf embedded [thermal printer module](https://www.amazon.com/dp/B0F1MYFZFM?ref_=ppx_hzsearch_conn_dt_b_fed_asin_title_2). This communicates with the microcontroller over a 9600-baud UART bus - normal text characters are encoded in ASCII, and other hardware instructions (e.g. line feeds, print head settings, etc.) are sent using special control codes.

Both the microcontroller and the printer take 5V DC power. In our prorotype unit, this is provided by a [5V 10A DC power supply](https://www.amazon.com/dp/B0G9GVBSTC?ref_=ppx_hzsearch_conn_dt_b_fed_asin_title_1) with a standard barrel jack connector. 

We also originally planned to include an RGB LED to indicate the status of the printer. The code for this was implemented in software, but this did not make it into our demo printer due to part sourcing constraints.

## Bill of Materials
For one printer:
* 1x ESP32-WROOM-32 Microcontroller
* 1x 5V 10A DC power supply
* 1x DC Barrel Jack breakout
* 1x Thermal printer module
* 1x RGB status LED
* 1x 3D printed shell
