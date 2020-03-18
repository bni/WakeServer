#import <Foundation/Foundation.h>

#import "wol.h"

#define STATE_OFF 0
#define STATE_STARTING 1
#define STATE_RUNNING 2
#define STATE_STOPPING 3

@interface StarMenuItem : NSObject {
    NSStatusItem *statusItem;

    int state;

    NSTimer *updateTimer;

    bool starEnabled;
    
    int nrTimerTicks;

    NSString *networkBroadcastAddress;
    NSString *serverHardwareAddress;

    NSString *serverShutdownCommand;
}

@end
