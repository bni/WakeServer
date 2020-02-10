#import "StarMenuItem.h"

@implementation StarMenuItem

- (void)dealloc
{
    [statusItem release];
    [updateTimer release];

    [super dealloc];    
}

- (void)mountServerVolume
{
    NSString *urlStringOfVolumeToMount = [[[NSString alloc] initWithFormat:@"%@://%@/%@",
                                           shareProtocol, serverName, shareName] autorelease];

    urlStringOfVolumeToMount = [urlStringOfVolumeToMount stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];

    NSURL *urlOfVolumeToMount = [[[NSURL alloc] initWithString:urlStringOfVolumeToMount] autorelease];

    OSErr error = -1;

    FSVolumeRefNum refNum;

    error = FSMountServerVolumeSync((CFURLRef)urlOfVolumeToMount, NULL,
                                    (CFStringRef)shareUsername, (CFStringRef)sharePassword,
                                    &refNum, FALSE);

    NSLog(@"mount status: %d", error);
}

- (void)unMountServerVolume
{
    NSError	*error = nil;

    NSString *volumeToUnMount = [[[NSString alloc] initWithFormat:@"/Volumes/%@", shareName] autorelease];

    [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL:[NSURL fileURLWithPath:volumeToUnMount] error:&error];
}

- (void)showHollowStar
{
    [statusItem setTitle:[NSString stringWithFormat:@"%C", 0x2606]];
    
    starEnabled = false;
}

- (void)showFilledStar
{
    [statusItem setTitle:[NSString stringWithFormat:@"%C", 0x2605]];
    
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

    if (nrTimerTicks == 65 && state == STATE_STARTING) {
        [updateTimer invalidate];
        updateTimer = nil;

        if ([serverMountCommand length] != 0) {
            const char *mount_command = [serverMountCommand UTF8String];
            fprintf(stdout, "mount_command: %s\n", mount_command);
            system(mount_command);
        }

        [self mountServerVolume];

        [self showFilledStar];

        state = STATE_RUNNING;
    }
}

- (IBAction)fireShutdownTimer:(id)sender
{
    [self doCountTick];

    if (nrTimerTicks == 20 && state == STATE_STOPPING) {
        [updateTimer invalidate];
        updateTimer = nil;

        [self showHollowStar];

        state = STATE_OFF;
    }
}

- (IBAction)clickStar:(id)sender
{
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

        [self unMountServerVolume];

        const char *shutdown_command = [serverShutdownCommand UTF8String];
        fprintf(stdout, "shutdown_command: %s\n", shutdown_command);
        system(shutdown_command);
    }
}

- (void)awakeFromNib
{
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setHighlightMode:YES];

    state = STATE_OFF;
    nrTimerTicks = 0;
    [self showHollowStar];

    [statusItem setEnabled:YES];
    [statusItem setToolTip:@"nexus"];
    
    [statusItem setAction:@selector(clickStar:)];
    
    [statusItem setTarget:self];

    // Read plist values here
    NSBundle* mainBundle = [NSBundle mainBundle];

    networkBroadcastAddress = [mainBundle objectForInfoDictionaryKey:@"WSNetworkBroadcastAddress"];
    NSLog(@"networkBroadcastAddress: %@", networkBroadcastAddress);

    serverHardwareAddress = [mainBundle objectForInfoDictionaryKey:@"WSServerHardwareAddress"];
    NSLog(@"serverHardwareAddress: %@", serverHardwareAddress);

    shareProtocol = [mainBundle objectForInfoDictionaryKey:@"WSShareProtocol"];
    NSLog(@"shareProtocol: %@", shareProtocol);

    serverName = [mainBundle objectForInfoDictionaryKey:@"WSServerName"];
    NSLog(@"serverName: %@", serverName);

    shareName = [mainBundle objectForInfoDictionaryKey:@"WSShareName"];
    NSLog(@"shareName: %@", shareName);

    shareUsername = [mainBundle objectForInfoDictionaryKey:@"WSShareUsername"];
    NSLog(@"shareUsername: %@", shareUsername);

    sharePassword = [mainBundle objectForInfoDictionaryKey:@"WSSharePassword"];
    NSLog(@"sharePassword: %@", sharePassword);

    serverMountCommand = [mainBundle objectForInfoDictionaryKey:@"WSServerMountCommand"];
    NSLog(@"serverMountCommand: %@", serverMountCommand);

    serverShutdownCommand = [mainBundle objectForInfoDictionaryKey:@"WSServerShutdownCommand"];
    NSLog(@"serverShutdownCommand: %@", serverShutdownCommand);
}

@end
