#import "headphone_scanner.h"
#import "remote_objc.h"
#import "sb_walk.h"

void scan_headphone_ui(void) {
    log_user("[HEADPHONE] Scanning for color F7CE46...\n");
    
    // Common classes for volume/audio UI
    const char *audioClasses[] = {
        "VolumeHUDView",
        "SystemVolumeView",
        "SBVolumeHUDView",
        "MediaRemoteVolumeIndicator",
        "AVSystemController"
    };
    
    uint64_t audioViews[64] = {0};
    int count = 0;
    
    for (size_t c = 0; c < sizeof(audioClasses)/sizeof(audioClasses[0]); c++) {
        uint64_t cls = r_class(audioClasses[c]);
        if (!cls) continue;
        
        uint64_t found[32] = {0};
        int n = sb_collect_views_in_windows(cls, found, 32);
        
        for (int i = 0; i < n && count < 64; i++) {
            audioViews[count++] = found[i];
            
            // Log this object
            char className[96] = {0};
            sb_read_class_name(found[i], className, sizeof(className));
            log_user("[HEADPHONE][FOUND] 0x%llx - %s\n", found[i], className);
            
            // Check its background color
            uint64_t bgColor = r_msg2_main(found[i], "backgroundColor", 0, 0, 0, 0);
            if (r_is_objc_ptr(bgColor)) {
                log_user("[HEADPHONE][COLOR] Found color object at 0x%llx\n", bgColor);
            }
        }
    }
    
    log_user("[HEADPHONE] Scanned %d audio UI objects.\n", count);
}

// Call this from main Infern0 interface
