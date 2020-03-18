#import "StarMenuItem.h"

@implementation StarMenuItem

- (void)dealloc
{
    [statusItem release];
    [updateTimer release];

    [super dealloc];    
}

- (void)showHollowStar
{
    statusItem.button.title = [NSString stringWithFormat:@"%C", 0x2606];

    starEnabled = false;
}

- (void)showFilledStar
{
    statusItem.button.title = [NSString stringWithFormat:@"%C", 0x2605];

    starEnabled = true;
}

- (void)doCountTick
{
    if (starEnabled) {
        [self showHollowStar];
    } else {
        [self showFilledStar];
    }

    nrTimerTicks++;

    NSLog(@"ticks: %d", nrTimerTicks);
}

- (IBAction)fireStartupTimer:(id)sender
{
    [self doCountTick];

    if (nrTimerTicks == 30 && state == STATE_STARTING) {
        [updateTimer invalidate];
        updateTimer = nil;

        [self showFilledStar];

        state = STATE_RUNNING;
    }
}

- (IBAction)fireShutdownTimer:(id)sender
{
    [self doCountTick];

    if (nrTimerTicks == 10 && state == STATE_STOPPING) {
        [updateTimer invalidate];
        updateTimer = nil;

        [self showHollowStar];

        state = STATE_OFF;
    }
}

- (IBAction)clickStar:(id)sender
{
    NSEvent *event = [NSApp currentEvent];

    if([event modifierFlags] & NSEventModifierFlagControl) {
        // Close the app on ctrl -click
        [NSApp terminate:self];
    } else {
        if (state == STATE_OFF) {
            state = STATE_STARTING;
            nrTimerTicks = 0;
            [self showFilledStar];

            updateTimer = [[NSTimer
                            scheduledTimerWithTimeInterval:(1.0)
                            target:self
                            selector:@selector(fireStartupTimer:)
                            userInfo:nil
                            repeats:YES] retain];

            unsigned char *broadcast_addr = (unsigned char*)[networkBroadcastAddress UTF8String];
            unsigned char *mac_addr = (unsigned char*)[serverHardwareAddress UTF8String];

            fprintf(stdout, "broadcast_addrr: %s\n", broadcast_addr);
            fprintf(stdout, "mac_addr: %s\n", mac_addr);

            if (send_wol_packet(broadcast_addr, mac_addr)) {
                NSLog(@"Error sending WOL packet");
            }
        } else if (state == STATE_RUNNING) {
            state = STATE_STOPPING;
            nrTimerTicks = 0;
            [self showHollowStar];

            updateTimer = [[NSTimer
                            scheduledTimerWithTimeInterval:(1.0)
                            target:self
                            selector:@selector(fireShutdownTimer:)
                            userInfo:nil
                            repeats:YES] retain];

            const char *shutdown_command = [serverShutdownCommand UTF8String];
            fprintf(stdout, "shutdown_command: %s\n", shutdown_command);
            system(shutdown_command);
        }
    }
}

- (void)awakeFromNib
{
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];

    state = STATE_OFF;
    nrTimerTicks = 0;
    [self showHollowStar];

    statusItem.button.enabled = YES;
    statusItem.button.action = @selector(clickStar:);
    statusItem.button.target = self;

    // Read plist values here
    NSBundle* mainBundle = [NSBundle mainBundle];

    networkBroadcastAddress = [mainBundle objectForInfoDictionaryKey:@"WSNetworkBroadcastAddress"];
    NSLog(@"networkBroadcastAddress: %@", networkBroadcastAddress);

    serverHardwareAddress = [mainBundle objectForInfoDictionaryKey:@"WSServerHardwareAddress"];
    NSLog(@"serverHardwareAddress: %@", serverHardwareAddress);

    serverShutdownCommand = [mainBundle objectForInfoDictionaryKey:@"WSServerShutdownCommand"];
    NSLog(@"serverShutdownCommand: %@", serverShutdownCommand);
}

@end
