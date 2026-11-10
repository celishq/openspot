#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#include <mach/mach_time.h>
#include <unistd.h>
#include "doomgeneric.h"
#include "doomkeys.h"
#include "doomstat.h"

/// The size of the queue of key presses and releases.
#define QUEUE_SIZE 256

static unsigned short queue[QUEUE_SIZE];
static unsigned int queueStart;
static unsigned int queueEnd;
static BOOL held[256];
/// The time in milliseconds between two pictures of the screen during play.
#define SCREEN_PAUSE 5000

/// The time in milliseconds after the start when `-screen` takes the title screen.
#define TITLE_TIME 1500

static NSWindow *window;
static NSView *screen;
static BOOL screenOnly;
static uint32_t started;
static uint32_t lastScreen;

/// Puts one press or release of a Doom key at the end of the queue, and drops it when the queue is full.
static void QueueKey(BOOL pressed, unsigned char key) {
    if (key == 0 || held[key] == pressed) return;
    unsigned int next = (queueEnd + 1) % QUEUE_SIZE;
    if (next == queueStart) return;
    held[key] = pressed;
    queue[queueEnd] = (unsigned short)((pressed ? 1 : 0) << 8 | key);
    queueEnd = next;
}

/// Releases each key that is held, so that the player stops when the window loses the focus.
static void ReleaseHeldKeys(void) {
    for (int key = 1; key < 256; key++) {
        if (held[key]) QueueKey(NO, (unsigned char)key);
    }
}

/// The Doom key of a key event, or 0 for a key that Doom does not use. Letters and digits follow the keyboard layout.
static unsigned char DoomKey(NSEvent *event) {
    switch (event.keyCode) {
    case kVK_LeftArrow: return KEY_LEFTARROW;
    case kVK_RightArrow: return KEY_RIGHTARROW;
    case kVK_UpArrow: return KEY_UPARROW;
    case kVK_DownArrow: return KEY_DOWNARROW;
    case kVK_Return: case kVK_ANSI_KeypadEnter: return KEY_ENTER;
    case kVK_Escape: return KEY_ESCAPE;
    case kVK_Tab: return KEY_TAB;
    case kVK_Space: return KEY_USE;
    case kVK_Delete: return KEY_BACKSPACE;
    case kVK_ANSI_Minus: return KEY_MINUS;
    case kVK_ANSI_Equal: return KEY_EQUALS;
    case kVK_F1: return KEY_F1;
    case kVK_F2: return KEY_F2;
    case kVK_F3: return KEY_F3;
    case kVK_F4: return KEY_F4;
    case kVK_F5: return KEY_F5;
    case kVK_F6: return KEY_F6;
    case kVK_F7: return KEY_F7;
    case kVK_F8: return KEY_F8;
    case kVK_F9: return KEY_F9;
    case kVK_F10: return KEY_F10;
    case kVK_F11: return KEY_F11;
    case kVK_F12: return KEY_F12;
    case kVK_Control: case kVK_RightControl: return KEY_FIRE;
    case kVK_Shift: case kVK_RightShift: return KEY_RSHIFT;
    case kVK_Option: case kVK_RightOption: return KEY_LALT;
    }
    if (event.type == NSEventTypeFlagsChanged) return 0;
    NSString *typed = event.charactersIgnoringModifiers.lowercaseString;
    if (typed.length != 1) return 0;
    unichar character = [typed characterAtIndex:0];
    return character >= 32 && character < 127 ? (unsigned char)character : 0;
}

/// Whether a modifier key of this event is down after the change.
static BOOL ModifierIsDown(NSEvent *event) {
    switch (event.keyCode) {
    case kVK_Control: case kVK_RightControl: return (event.modifierFlags & NSEventModifierFlagControl) != 0;
    case kVK_Shift: case kVK_RightShift: return (event.modifierFlags & NSEventModifierFlagShift) != 0;
    case kVK_Option: case kVK_RightOption: return (event.modifierFlags & NSEventModifierFlagOption) != 0;
    }
    return NO;
}

/// The view that shows the screen of the game in its layer and gives each key to the queue. Key repeats are dropped.
@interface DoomView : NSView
@end

@implementation DoomView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    if (event.modifierFlags & NSEventModifierFlagCommand) {
        [super keyDown:event];
    } else if (!event.isARepeat) {
        QueueKey(YES, DoomKey(event));
    }
}

- (void)keyUp:(NSEvent *)event {
    QueueKey(NO, DoomKey(event));
}

- (void)flagsChanged:(NSEvent *)event {
    QueueKey(ModifierIsDown(event), DoomKey(event));
}

@end

/// Ends the game when its window closes, and releases the keys when the window loses the focus.
@interface DoomWindowWatch : NSObject <NSWindowDelegate>
@end

@implementation DoomWindowWatch

- (void)windowWillClose:(NSNotification *)notification {
    exit(0);
}

- (void)windowDidResignKey:(NSNotification *)notification {
    ReleaseHeldKeys();
}

@end

static DoomWindowWatch *watch;

/// A menu bar with one Quit item on ⌘Q.
static NSMenu *MainMenu(void) {
    NSMenu *bar = [[NSMenu alloc] init];
    NSMenuItem *item = [[NSMenuItem alloc] init];
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"Quit Doom" action:@selector(terminate:) keyEquivalent:@"q"];
    item.submenu = menu;
    [bar addItem:item];
    return bar;
}

void DG_Init(void) {
    if (screenOnly) return;
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 480)
                                         styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    window.title = @"Doom";
    window.contentAspectRatio = NSMakeSize(4, 3);
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    window.releasedWhenClosed = NO;
    watch = [[DoomWindowWatch alloc] init];
    window.delegate = watch;
    screen = [[DoomView alloc] initWithFrame:NSMakeRect(0, 0, 640, 480)];
    screen.wantsLayer = YES;
    screen.layer.contentsGravity = kCAGravityResize;
    screen.layer.magnificationFilter = kCAFilterNearest;
    screen.layer.backgroundColor = NSColor.blackColor.CGColor;
    window.contentView = screen;
    [window center];
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:screen];
    [NSApp activate];
}

/// The screen buffer of the engine as an image. Each pixel is 0x00RRGGBB.
static CGImageRef ScreenImage(void) {
    static CGColorSpaceRef space;
    if (space == NULL) space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    size_t bytes = DOOMGENERIC_RESX * DOOMGENERIC_RESY * 4;
    CFDataRef data = CFDataCreate(NULL, (const UInt8 *)DG_ScreenBuffer, (CFIndex)bytes);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGImageRef image = CGImageCreate(DOOMGENERIC_RESX, DOOMGENERIC_RESY, 8, 32, DOOMGENERIC_RESX * 4, space,
                                     kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst, provider, NULL, false,
                                     kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CFRelease(data);
    return image;
}

/// Writes the screen as a new PNG of 640×480 pixels, the 4:3 shape of the original monitors, to `screens/`, and removes
/// the older pictures there. A new name each time keeps a cache from showing an old picture.
static void SaveScreen(void) {
    NSFileManager *files = NSFileManager.defaultManager;
    [files createDirectoryAtPath:@"screens" withIntermediateDirectories:YES attributes:nil error:nil];
    CGImageRef frame = ScreenImage();
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, 640, 480, 8, 0, space, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextDrawImage(context, CGRectMake(0, 0, 640, 480), frame);
    CGImageRef picture = CGBitmapContextCreateImage(context);
    NSString *next = @"screens/.next.png";
    CGImageDestinationRef file = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:next], CFSTR("public.png"), 1, NULL);
    CGImageDestinationAddImage(file, picture, NULL);
    if (CGImageDestinationFinalize(file)) {
        for (NSString *name in [files contentsOfDirectoryAtPath:@"screens" error:nil]) {
            if ([name hasPrefix:@"screen-"]) [files removeItemAtPath:[@"screens" stringByAppendingPathComponent:name] error:nil];
        }
        NSString *name = [NSString stringWithFormat:@"screens/screen-%.0f.png", NSDate.date.timeIntervalSince1970 * 1000];
        [files moveItemAtPath:next toPath:name error:nil];
    }
    CFRelease(file);
    CGImageRelease(picture);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    CGImageRelease(frame);
}

/// Handles each window event that waits, and returns at once when none waits.
static void HandleEvents(void) {
    NSEvent *event;
    while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES])) {
        [NSApp sendEvent:event];
    }
}

void DG_DrawFrame(void) {
    uint32_t now = DG_GetTicksMs();
    if (screenOnly) {
        if (now - started < TITLE_TIME) return;
        SaveScreen();
        exit(0);
    }
    if (now - lastScreen >= SCREEN_PAUSE && gamestate == GS_LEVEL && !menuactive && !paused) {
        SaveScreen();
        lastScreen = now;
    }
    CGImageRef image = ScreenImage();
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    screen.layer.contents = (__bridge id)image;
    [CATransaction commit];
    CGImageRelease(image);
    HandleEvents();
}

void DG_SleepMs(uint32_t ms) {
    usleep(ms * 1000);
}

uint32_t DG_GetTicksMs(void) {
    static mach_timebase_info_data_t base;
    if (base.denom == 0) mach_timebase_info(&base);
    return (uint32_t)(mach_absolute_time() * base.numer / base.denom / 1000000);
}

int DG_GetKey(int *pressed, unsigned char *key) {
    if (queueStart == queueEnd) return 0;
    unsigned short data = queue[queueStart];
    queueStart = (queueStart + 1) % QUEUE_SIZE;
    *pressed = data >> 8;
    *key = data & 0xFF;
    return 1;
}

void DG_SetWindowTitle(const char *title) {
    window.title = [NSString stringWithUTF8String:title];
}

/// Starts the app with a Dock icon and a menu, then runs the game until it quits. With `-screen`, it opens no window,
/// writes the title screen to `screens/` and ends.
int main(int argc, char **argv) {
    started = DG_GetTicksMs();
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-screen") == 0) screenOnly = YES;
    }
    @autoreleasepool {
        if (!screenOnly) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            NSApp.mainMenu = MainMenu();
            [NSApp finishLaunching];
        }
        doomgeneric_Create(argc, argv);
    }
    for (;;) {
        @autoreleasepool {
            doomgeneric_Tick();
        }
    }
}
