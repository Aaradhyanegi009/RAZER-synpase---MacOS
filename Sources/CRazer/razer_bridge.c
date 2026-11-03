#include "razer_bridge.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#define RAZER_VENDOR_ID 5426 // 0x1532
#define RAZER_DEATHADDER_ESSENTIAL_2021 152 // 0x0098
#define RAZER_DEATHADDER_ESSENTIAL_2018 113 // 0x0071
#define RAZER_REPORT_LEN 90

static unsigned char calculate_crc(const unsigned char *report) {
    unsigned char crc = 0;
    for (int i = 2; i < 88; i++) {
        crc ^= report[i];
    }
    return crc;
}

static io_service_t find_razer_service(void) {
    int pids[] = {RAZER_DEATHADDER_ESSENTIAL_2021, RAZER_DEATHADDER_ESSENTIAL_2018, 0};
    for (int i = 0; pids[i] != 0; i++) {
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        if (!matchingDict) continue;
        
        int vendor = RAZER_VENDOR_ID;
        int product = pids[i];
        CFNumberRef vNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &vendor);
        CFNumberRef pNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &product);
        CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), vNum);
        CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), pNum);
        CFRelease(vNum);
        CFRelease(pNum);
        
        io_iterator_t iterator;
        kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator);
        if (kr == KERN_SUCCESS) {
            io_service_t usbDevice = IOIteratorNext(iterator);
            IOObjectRelease(iterator);
            if (usbDevice) return usbDevice;
        }
    }
    return 0;
}

static IOUSBDeviceInterface **get_razer_device(void) {
    io_service_t usbDevice = find_razer_service();
    if (!usbDevice) return NULL;
    
    IOCFPlugInInterface **plugInInterface = NULL;
    SInt32 score;
    kern_return_t kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
    IOObjectRelease(usbDevice);
    if (kr != KERN_SUCCESS || !plugInInterface) return NULL;
    
    IOUSBDeviceInterface **dev = NULL;
    HRESULT res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID*)&dev);
    (*plugInInterface)->Release(plugInInterface);
    if (res != S_OK || !dev) return NULL;
    
    return dev;
}

static bool send_and_recv_on_dev(IOUSBDeviceInterface **dev, unsigned char *report, unsigned char *response) {
    report[88] = calculate_crc(report);
    report[89] = 0x00;
    
    IOUSBDevRequest req;
    req.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBClass, kUSBInterface);
    req.bRequest = 0x09; // SET_REPORT
    req.wValue = 0x0300; // Feature report, ID 0
    req.wIndex = 0;      // Interface 0
    req.wLength = RAZER_REPORT_LEN;
    req.pData = report;
    
    IOReturn ret = (*dev)->DeviceRequest(dev, &req);
    if (ret != kIOReturnSuccess) return false;
    
    usleep(2000); // Wait 2ms for Razer MCU to process report
    
    unsigned char resp_buf[RAZER_REPORT_LEN] = {0};
    IOUSBDevRequest getReq;
    getReq.bmRequestType = USBmakebmRequestType(kUSBIn, kUSBClass, kUSBInterface);
    getReq.bRequest = 0x01; // GET_REPORT
    getReq.wValue = 0x0300;
    getReq.wIndex = 0;
    getReq.wLength = RAZER_REPORT_LEN;
    getReq.pData = resp_buf;
    
    (*dev)->DeviceRequest(dev, &getReq);
    usleep(1000);
    
    if (response) {
        memcpy(response, resp_buf, RAZER_REPORT_LEN);
    }
    return (resp_buf[0] == 0x02 || ret == kIOReturnSuccess);
}

static bool send_razer_report(unsigned char *report, unsigned char *response) {
    IOUSBDeviceInterface **dev = get_razer_device();
    if (!dev) return false;
    
    IOReturn openRet = (*dev)->USBDeviceOpen(dev);
    if (openRet != kIOReturnSuccess) {
        (*dev)->Release(dev);
        return false;
    }
    
    bool ok = send_and_recv_on_dev(dev, report, response);
    
    (*dev)->USBDeviceClose(dev);
    (*dev)->Release(dev);
    return ok;
}

bool razer_is_connected(void) {
    io_service_t dev = find_razer_service();
    if (dev) {
        IOObjectRelease(dev);
        return true;
    }
    return false;
}

int razer_get_dpi(void) {
    unsigned char report[RAZER_REPORT_LEN] = {0};
    unsigned char resp[RAZER_REPORT_LEN] = {0};
    report[1] = 0xFF;
    report[5] = 0x07;
    report[6] = 0x04;
    report[7] = 0x85; // get_dpi_xy
    report[8] = 0x00; // NOSTORE
    
    if (send_razer_report(report, resp) && resp[0] == 0x02) {
        int dpi = (resp[9] << 8) | resp[10];
        if (dpi >= 100 && dpi <= 6400) return dpi;
    }
    return 1600;
}

int razer_get_polling_rate(void) {
    unsigned char report[RAZER_REPORT_LEN] = {0};
    unsigned char resp[RAZER_REPORT_LEN] = {0};
    report[1] = 0xFF;
    report[5] = 0x01;
    report[6] = 0x00;
    report[7] = 0x85; // get_polling_rate
    
    if (send_razer_report(report, resp) && resp[0] == 0x02) {
        switch (resp[8]) {
            case 0x01: return 1000;
            case 0x02: return 500;
            case 0x08: return 125;
        }
    }
    return 1000;
}

int razer_get_led_brightness(void) {
    unsigned char report[RAZER_REPORT_LEN] = {0};
    unsigned char resp[RAZER_REPORT_LEN] = {0};
    report[1] = 0x3F; // Extended Matrix Transaction ID
    report[5] = 0x03;
    report[6] = 0x0F; // Extended Matrix Class
    report[7] = 0x84; // get_extended_matrix_brightness
    report[8] = 0x01; // VARSTORE
    report[9] = 0x04; // LOGO_LED
    
    if (send_razer_report(report, resp) && resp[0] == 0x02) {
        return (int)resp[10];
    }
    return 255;
}

bool razer_set_dpi(uint16_t dpi) {
    if (dpi < 100) dpi = 100;
    if (dpi > 6400) dpi = 6400;
    
    unsigned char report[RAZER_REPORT_LEN] = {0};
    report[1] = 0xFF; // Transaction ID
    report[5] = 0x07; // Data size
    report[6] = 0x04; // Command Class (DPI)
    report[7] = 0x05; // Command ID (set_dpi_xy)
    report[8] = 0x01; // VARSTORE (Save to hardware memory)
    
    report[9]  = (dpi >> 8) & 0xFF;
    report[10] = dpi & 0xFF;
    report[11] = (dpi >> 8) & 0xFF;
    report[12] = dpi & 0xFF;
    
    return send_razer_report(report, NULL);
}

bool razer_set_polling_rate(uint16_t rate) {
    unsigned char rate_code = 0x01; // 1000 Hz default
    if (rate <= 125) {
        rate_code = 0x08; // 125 Hz
    } else if (rate <= 500) {
        rate_code = 0x02; // 500 Hz
    } else {
        rate_code = 0x01; // 1000 Hz
    }
    
    unsigned char report[RAZER_REPORT_LEN] = {0};
    report[1] = 0xFF;
    report[5] = 0x01; // Data size
    report[6] = 0x00; // Command Class
    report[7] = 0x05; // Command ID: set_polling_rate
    report[8] = rate_code;
    
    return send_razer_report(report, NULL);
}

bool razer_set_led(uint8_t effect, uint8_t brightness, uint8_t r, uint8_t g, uint8_t b) {
    IOUSBDeviceInterface **dev = get_razer_device();
    if (!dev) return false;
    
    if ((*dev)->USBDeviceOpen(dev) != kIOReturnSuccess) {
        (*dev)->Release(dev);
        return false;
    }
    
    // Ensure green channel is active on single-color green LED if color is non-black
    uint8_t eff_g = (g == 0 && (r > 0 || b > 0)) ? 0xFF : g;
    uint8_t led_ids[2] = {0x04, 0x00}; // LOGO_LED (0x04) and ZERO_LED (0x00)
    
    for (int i = 0; i < 2; i++) {
        uint8_t led_id = led_ids[i];
        
        // 1. Extended Matrix Brightness (Class 0x0F, CMD 0x04, Size 0x03, Trans 0x3F)
        unsigned char b_report[RAZER_REPORT_LEN] = {0};
        b_report[1] = 0x3F; // Required Transaction ID for DeathAdder Essential 2021
        b_report[5] = 0x03; // Data size
        b_report[6] = 0x0F; // Extended Matrix Class
        b_report[7] = 0x04; // set_extended_matrix_brightness
        b_report[8] = 0x01; // VARSTORE
        b_report[9] = led_id;
        b_report[10] = (effect == 0) ? 0 : brightness;
        send_and_recv_on_dev(dev, b_report, NULL);
        
        // 2. Extended Matrix Effect (Class 0x0F, CMD 0x02, Trans 0x3F)
        unsigned char e_report[RAZER_REPORT_LEN] = {0};
        e_report[1] = 0x3F;
        e_report[6] = 0x0F;
        e_report[7] = 0x02; // set_extended_matrix_effect
        e_report[8] = 0x01; // VARSTORE
        e_report[9] = led_id;
        
        if (effect == 0 || brightness == 0) {
            // OFF / NONE (effect_id = 0x00, size = 0x06)
            e_report[5] = 0x06;
            e_report[10] = 0x00;
        } else if (effect == 1) {
            // STATIC (effect_id = 0x01, size = 0x09)
            e_report[5] = 0x09;
            e_report[10] = 0x01;
            e_report[13] = 0x01;
            e_report[14] = r;
            e_report[15] = eff_g;
            e_report[16] = b;
        } else if (effect == 2) {
            // BREATHING SINGLE (effect_id = 0x02, size = 0x09)
            e_report[5] = 0x09;
            e_report[10] = 0x02;
            e_report[11] = 0x01; // Single color breathing
            e_report[13] = 0x01;
            e_report[14] = r;
            e_report[15] = eff_g;
            e_report[16] = b;
        } else if (effect == 3) {
            // REACTIVE CLICK (effect_id = 0x05, size = 0x09)
            e_report[5] = 0x09;
            e_report[10] = 0x05;
            e_report[12] = 0x02; // Speed (1-4)
            e_report[13] = 0x01;
            e_report[14] = r;
            e_report[15] = eff_g;
            e_report[16] = b;
        }
        send_and_recv_on_dev(dev, e_report, NULL);
    }
    
    (*dev)->USBDeviceClose(dev);
    (*dev)->Release(dev);
    return true;
}
