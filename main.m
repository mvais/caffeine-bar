#import <AppKit/AppKit.h>

// ponytail: ObjC port of main.swift — the installed Swift CLT is broken (SDK/compiler
// mismatch); clang compiles this fine. Same design: menu bar toggle around /usr/bin/caffeinate.
@interface App : NSObject <NSApplicationDelegate>
@property (strong) NSStatusItem *statusItem;
@property (strong) NSTask *task;
@property (strong) NSMutableSet<NSString *> *enabledFlags;
@property NSInteger timeoutSeconds; // 0 = indefinitely
@end

@implementation App

static NSArray<NSArray *> *Flags(void) {
    return @[
        @[@"-d", @"Prevent display sleep"],
        @[@"-i", @"Prevent idle system sleep"],
        @[@"-m", @"Prevent disk sleep"],
        @[@"-s", @"Prevent sleep on AC power"],
        @[@"-u", @"Declare user is active"],
    ];
}

static NSArray<NSArray *> *Durations(void) {
    return @[
        @[@"Indefinitely", @0],
        @[@"15 minutes", @(15 * 60)],
        @[@"30 minutes", @(30 * 60)],
        @[@"1 hour", @3600],
        @[@"2 hours", @(2 * 3600)],
        @[@"4 hours", @(4 * 3600)],
        @[@"8 hours", @(8 * 3600)],
    ];
}

- (BOOL)isActive { return self.task != nil && self.task.isRunning; }

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.enabledFlags = [NSMutableSet setWithArray:@[@"-d", @"-i"]];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.action = @selector(clicked);
    self.statusItem.button.target = self;
    [self.statusItem.button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
    [self updateIcon];
}

- (void)clicked {
    NSEvent *event = NSApp.currentEvent;
    if (event.type == NSEventTypeRightMouseUp || (event.modifierFlags & NSEventModifierFlagControl)) {
        [self showMenu];
        return;
    }
    self.isActive ? [self stop] : [self start];
}

- (void)showMenu {
    NSMenu *menu = [NSMenu new];

    NSMenuItem *status = [[NSMenuItem alloc] initWithTitle:self.isActive ? @"Caffeinate: On" : @"Caffeinate: Off"
                                                    action:nil keyEquivalent:@""];
    status.enabled = NO;
    [menu addItem:status];
    [menu addItemWithTitle:self.isActive ? @"Disable" : @"Enable"
                    action:@selector(toggleFromMenu) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];

    for (NSArray *f in Flags()) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:f[1] action:@selector(toggleFlag:) keyEquivalent:@""];
        item.representedObject = f[0];
        item.state = [self.enabledFlags containsObject:f[0]] ? NSControlStateValueOn : NSControlStateValueOff;
        [menu addItem:item];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    NSMenu *durMenu = [NSMenu new];
    for (NSArray *d in Durations()) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:d[0] action:@selector(setDuration:) keyEquivalent:@""];
        item.representedObject = d[1];
        item.state = self.timeoutSeconds == [d[1] integerValue] ? NSControlStateValueOn : NSControlStateValueOff;
        item.target = self;
        [durMenu addItem:item];
    }
    NSMenuItem *durItem = [[NSMenuItem alloc] initWithTitle:@"Duration" action:nil keyEquivalent:@""];
    durItem.submenu = durMenu;
    [menu addItem:durItem];

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@"q"];

    for (NSMenuItem *item in menu.itemArray) if (item.action) item.target = self;
    self.statusItem.menu = menu;
    [self.statusItem.button performClick:nil];
    self.statusItem.menu = nil; // so plain left-click keeps toggling
}

- (void)toggleFromMenu { self.isActive ? [self stop] : [self start]; }

- (void)toggleFlag:(NSMenuItem *)sender {
    NSString *flag = sender.representedObject;
    if ([self.enabledFlags containsObject:flag]) [self.enabledFlags removeObject:flag];
    else [self.enabledFlags addObject:flag];
    if (self.enabledFlags.count == 0) [self.enabledFlags addObject:@"-i"]; // bare caffeinate = -i anyway
    if (self.isActive) { [self stop]; [self start]; } // apply new flags immediately
}

- (void)setDuration:(NSMenuItem *)sender {
    self.timeoutSeconds = [sender.representedObject integerValue];
    if (self.isActive) { [self stop]; [self start]; }
}

- (void)start {
    NSTask *t = [NSTask new];
    t.executableURL = [NSURL fileURLWithPath:@"/usr/bin/caffeinate"];
    NSMutableArray *args = [[self.enabledFlags.allObjects
        sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    if (self.timeoutSeconds > 0)
        [args addObjectsFromArray:@[@"-t", [NSString stringWithFormat:@"%ld", (long)self.timeoutSeconds]]];
    t.arguments = args;
    __weak App *weakSelf = self;
    t.terminationHandler = ^(NSTask *ended) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.task == ended) weakSelf.task = nil; // e.g. -t timeout expired
            [weakSelf updateIcon];
        });
    };
    NSError *err = nil;
    if ([t launchAndReturnError:&err]) self.task = t;
    else NSBeep();
    [self updateIcon];
}

- (void)stop {
    NSTask *t = self.task;
    self.task = nil;
    [t terminate];
    [self updateIcon];
}

- (void)updateIcon {
    NSString *name = self.isActive ? @"cup.and.saucer.fill" : @"cup.and.saucer";
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:@"Caffeinate"];
    if (self.isActive) {
        // bake the color into the image — NSStatusBarButton ignores contentTintColor
        // on template images and just draws them in the menu bar color
        image = [image imageWithSymbolConfiguration:
            [NSImageSymbolConfiguration configurationWithPaletteColors:@[[NSColor systemGreenColor]]]];
        image.template = NO;
    }
    self.statusItem.button.image = image;
    self.statusItem.button.toolTip = self.isActive ? @"Caffeinate is on — click to disable"
                                                   : @"Caffeinate is off — click to enable";
}

- (void)quit { [self stop]; [NSApp terminate:nil]; }
- (void)applicationWillTerminate:(NSNotification *)note { [self stop]; }

@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        App *delegate = [App new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; // menu bar only, no Dock
        [app run];
    }
    return 0;
}
