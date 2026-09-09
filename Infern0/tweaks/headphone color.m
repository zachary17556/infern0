//
// headphone_color.m
// Infern0 - Headphone Level Color Modifier
//
// Scans and modifies the headphone/volume level indicator color
// from F7CE46 (yellow/gold) to red or any custom color
//

#import "headphone_color.h"
#import "remote_objc.h"
#import "sb_walk.h"
#import "../LogTextView.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define HEADPHONE_MAX_VIEWS 32
#define HEADPHONE_MAX_COLORS 64

typedef struct {
    uint64_t object;
    uint64_t originalColor;
    const char *propertyName;  // "backgroundColor", "tintColor", etc.
} HeadphoneColorState;

static HeadphoneColorState gHeadphoneColors[HEADPHONE_MAX_COLORS];
static int gHeadphoneColorCount = 0;
static bool gHeadphoneApplied = false;

// Target color to find: F7CE46 (RGB: 247, 206, 70)
static uint8_t gTargetColorRGB[3] = {0xF7, 0xCE, 0x46};
static char gNewColorHex[16] = "#FF0000";  // Red by default

// Forward declarations
static void headphone_scan_for_color(void);
static uint64_t headphone_create_color(const char *hexColor);

// Utility: Convert hex color string to UIColor
static UIColor *headphone_hex_to_color(const char *raw, CGFloat alpha)
{
    NSString *hex = [NSString stringWithUTF8String:(raw ? raw : "")] ?: @"";
    hex = [[hex stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    
    if (hex.length != 6) hex = @"FF0000";  // Default to red
    
    unsigned value = 0;
    [[NSScanner scannerWithString:hex] scanHexInt:&value];
    
    return [UIColor colorWithRed:((value >> 16) & 0xff) / 255.0
                          green:((value >> 8) & 0xff) / 255.0
                           blue:(value & 0xff) / 255.0
                          alpha:alpha];
}

// Create a remote UIColor object in SpringBoard
static uint64_t headphone_remote_color(const char *hexColor, double alphaScale)
{
    UIColor *local = headphone_hex_to_color(hexColor, alphaScale);
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [local getRed:&red green:&green blue:&blue alpha:&alpha];
    
    double r = red, g = green, b = blue, a = alpha;
    uint64_t cls = r_class("UIColor");
    
    if (!cls) return 0;
    
    return r_msg2_main_raw(cls, "colorWithRed:green:blue:alpha:",
                          &r, sizeof(r), &g, sizeof(g),
                          &b, sizeof(b), &a, sizeof(a));
}

// Check if two colors are approximately equal
static bool headphone_colors_equal(uint64_t color1, uint64_t color2)
{
    if (!r_is_objc_ptr(color1) || !r_is_objc_ptr(color2)) return false;
    
    // Get red component from both
    uint64_t red1 = r_msg2_main(color1, "redComponent", 0, 0, 0, 0);
    uint64_t red2 = r_msg2_main(color2, "redComponent", 0, 0, 0, 0);
    
    // This is a simplified check - in real use, compare all RGBA components
    // For now, just check if objects are the same
    return color1 == color2;
}

// Helper: Check if object has already been captured
static bool headphone_already_captured(uint64_t object)
{
    for (int i = 0; i < gHeadphoneColorCount; i++) {
        if (gHeadphoneColors[i].object == object) return true;
    }
    return false;
}

// Helper: Capture an object's color state
static bool headphone_capture_color_state(uint64_t object, const char *getter, const char *setter)
{
    if (!r_is_objc_ptr(object) || headphone_already_captured(object) ||
        gHeadphoneColorCount >= HEADPHONE_MAX_COLORS ||
        !r_responds_main(object, getter) ||
        !r_responds_main(object, setter)) {
        return false;
    }
    
    uint64_t original = r_msg2_main(object, getter, 0, 0, 0, 0);
    
    if (r_is_objc_ptr(original)) {
        original = r_dlsym_call(R_TIMEOUT, "objc_retain", original, 0, 0, 0, 0, 0, 0, 0);
    }
    
    gHeadphoneColors[gHeadphoneColorCount++] = (HeadphoneColorState){
        object, original, getter
    };
    
    return true;
}

// Main scanning function
static void headphone_scan_for_color(void)
{
    log_user("[HEADPHONE][SCAN] Starting scan for volume/headphone UI elements...\n");
    
    // Classes that typically contain the headphone/volume level UI
    const char *volumeClasses[] = {
        "VolumeHUDView",
        "SBVolumeHUDView",
        "AVSystemController",
        "MediaRemoteVolumeIndicator",
        "SystemVolumeView",
        "MPVolumeView",
        "UISlider",
        "CALayer"
    };
    
    uint64_t volumeViews[HEADPHONE_MAX_VIEWS] = {0};
    int totalFound = 0;
    
    // Scan each class type
    for (size_t c = 0; c < sizeof(volumeClasses) / sizeof(volumeClasses[0]); c++) {
        uint64_t cls = r_class(volumeClasses[c]);
        if (!cls) continue;
        
        uint64_t found[HEADPHONE_MAX_VIEWS] = {0};
        int n = sb_collect_views_in_windows(cls, found, HEADPHONE_MAX_VIEWS);
        
        log_user("[HEADPHONE][SCAN] Class '%s': found %d instances\n", volumeClasses[c], n);
        
        for (int i = 0; i < n && totalFound < HEADPHONE_MAX_VIEWS; i++) {
            uint64_t obj = found[i];
            
            // Try to capture backgroundColor
            if (headphone_capture_color_state(obj, "backgroundColor", "setBackgroundColor:")) {
                char className[96] = {0};
                sb_read_class_name(obj, className, sizeof(className));
                log_user("[HEADPHONE][FOUND] Captured backgroundColor from 0x%llx (%s)\n", 
                        obj, className[0] ? className : "unknown");
                totalFound++;
            }
            
            // Try to capture tintColor
            if (headphone_capture_color_state(obj, "tintColor", "setTintColor:")) {
                char className[96] = {0};
                sb_read_class_name(obj, className, sizeof(className));
                log_user("[HEADPHONE][FOUND] Captured tintColor from 0x%llx (%s)\n", 
                        obj, className[0] ? className : "unknown");
                totalFound++;
            }
        }
    }
    
    log_user("[HEADPHONE][SCAN] Complete. Found %d total color objects to monitor.\n", 
            gHeadphoneColorCount);
}

// Public API: Configure the new color
void headphone_configure_color(const char *hexColor)
{
    if (!hexColor || !hexColor[0]) {
        headphone_hex_to_color("#FF0000", 1.0);  // Default to red
        return;
    }
    
    snprintf(gNewColorHex, sizeof(gNewColorHex), "%s", hexColor);
    log_user("[HEADPHONE][CONFIG] New color configured: %s\n", gNewColorHex);
}

// Public API: Apply the color change
bool headphone_apply_in_session(void)
{
    if (gHeadphoneApplied) {
        log_user("[HEADPHONE][WARN] Color already applied. Use headphone_stop_in_session() first.\n");
        return false;
    }
    
    // First scan for all UI elements
    headphone_scan_for_color();
    
    if (gHeadphoneColorCount == 0) {
        log_user("[HEADPHONE][ERROR] No headphone/volume UI elements found to modify.\n");
        return false;
    }
    
    // Create the new color remotely
    uint64_t newColor = headphone_remote_color(gNewColorHex, 1.0);
    
    if (!r_is_objc_ptr(newColor)) {
        log_user("[HEADPHONE][ERROR] Failed to create remote color %s\n", gNewColorHex);
        return false;
    }
    
    // Apply the new color to all captured views
    int colorCount = 0;
    for (int i = 0; i < gHeadphoneColorCount; i++) {
        HeadphoneColorState state = gHeadphoneColors[i];
        
        if (!r_is_objc_ptr(state.object)) continue;
        
        // Determine the setter method name
        const char *setter = NULL;
        if (strcmp(state.propertyName, "backgroundColor") == 0) {
            setter = "setBackgroundColor:";
        } else if (strcmp(state.propertyName, "tintColor") == 0) {
            setter = "setTintColor:";
        }
        
        if (setter && r_responds_main(state.object, setter)) {
            r_msg2_main(state.object, setter, newColor, 0, 0, 0);
            colorCount++;
            
            char className[96] = {0};
            sb_read_class_name(state.object, className, sizeof(className));
            log_user("[HEADPHONE][APPLY] Changed %s on 0x%llx (%s)\n", 
                    setter, state.object, className[0] ? className : "unknown");
        }
    }
    
    gHeadphoneApplied = true;
    
    log_user("[HEADPHONE][OK] Applied color %s to %d UI element(s).\n", gNewColorHex, colorCount);
    return colorCount > 0;
}

// Public API: Restore original colors
bool headphone_stop_in_session(void)
{
    if (!gHeadphoneApplied) {
        log_user("[HEADPHONE][WARN] Color not currently applied.\n");
        return false;
    }
    
    bool ok = true;
    int restored = 0;
    
    for (int i = gHeadphoneColorCount - 1; i >= 0; i--) {
        HeadphoneColorState state = gHeadphoneColors[i];
        
        if (!r_is_objc_ptr(state.object)) {
            ok = false;
            continue;
        }
        
        // Determine the setter
        const char *setter = NULL;
        if (strcmp(state.propertyName, "backgroundColor") == 0) {
            setter = "setBackgroundColor:";
        } else if (strcmp(state.propertyName, "tintColor") == 0) {
            setter = "setTintColor:";
        }
        
        if (setter && r_responds_main(state.object, setter)) {
            r_msg2_main(state.object, setter, state.originalColor, 0, 0, 0);
            restored++;
        }
        
        // Release the retained original color
        if (r_is_objc_ptr(state.originalColor)) {
            r_dlsym_call(R_TIMEOUT, "objc_release", state.originalColor, 0, 0, 0, 0, 0, 0, 0);
        }
    }
    
    log_user("[HEADPHONE][RESTORE] Restored %d color(s); result=%s.\n", restored, ok ? "clean" : "partial");
    
    // Clear state
    memset(gHeadphoneColors, 0, sizeof(gHeadphoneColors));
    gHeadphoneColorCount = 0;
    gHeadphoneApplied = false;
    
    return ok;
}

// Public API: Forget about captured objects
void headphone_forget_state(void)
{
    memset(gHeadphoneColors, 0, sizeof(gHeadphoneColors));
    gHeadphoneColorCount = 0;
    gHeadphoneApplied = false;
    log_user("[HEADPHONE][FORGET] State cleared.\n");
}
