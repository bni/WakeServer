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
    NSString *serverAddress = @"nexus";
    NSString *volumeName = @"Media";
    
    NSString *username = @"";
    NSString *password = @"";
    
    NSString *urlStringOfVolumeToMount = [[[NSString alloc] initWithFormat:@"smb://%@/%@", serverAddress, volumeName] autorelease];
    urlStringOfVolumeToMount = [urlStringOfVolumeToMount stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
    
    NSURL *urlOfVolumeToMount = [[[NSURL alloc] initWithString:urlStringOfVolumeToMount] autorelease];
    
    OSErr error = -1;
    
    FSVolumeRefNum refNum;
    
    error = FSMountServerVolumeSync((CFURLRef) urlOfVolumeToMount, NULL, (CFStringRef) username, (CFStringRef) password, &refNum, FALSE);
    
    NSLog(@"mount status: %d", error);
}

- (void)unMountServerVolume
{
    NSError	*error = nil;
    [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL:[NSURL fileURLWithPath:@"/Volumes/Media"] error:&error];
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

    if (nrTimerTicks == 90 && state == STATE_STARTING) {
        [updateTimer invalidate];
        updateTimer = nil;

        system("ssh -t -t 10.0.1.8 'exec 3< /etc/cryptmount/secrets; cryptmount --all --passwd-fd 3'");

        [self mountServerVolume];

        [self showFilledStar];

        state = STATE_RUNNING;
    }
}

- (IBAction)fireShutdownTimer:(id)sender
{
    [self doCountTick];

    if (nrTimerTicks == 30 && state == STATE_STOPPING) {
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
        
        unsigned char broadcast_addr[14] = "10.0.1.255";
        unsigned char mac_addr[18] = "00:0c:6e:50:8c:1a";
        
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

        system("ssh -t 10.0.1.8 'shutdown -h now'");
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
}

@end
