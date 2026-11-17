#import "MySQLPref.h"

static NSString * const kDefaultsSuite   = @"com.zhaozc.MySQLPrefPane";
static NSString * const kInstallPathKey  = @"MySQLInstallPath";
static NSString * const kDefaultPath     = @"/usr/local/mysql";
static NSString * const kLaunchDaemonPlist = @"/Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist";
static NSString * const kLaunchDaemonLabel = @"system/com.oracle.oss.mysql.mysqld";

@implementation MySQLPref {
    NSTextField *_statusLabel;
    NSTextField *_versionLabel;
    NSTextField *_pathField;
    NSTextField *_hintLabel;
    NSSwitch    *_serviceSwitch;
    NSButton    *_restartButton;
    NSTimer     *_statusTimer;
    BOOL         _updatingSwitch;
    BOOL         _busy;
}

#pragma mark - 偏好设置面板生命周期

- (NSView *)loadMainView
{
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 668, 340)];

    NSImageView *logo = [[NSImageView alloc] initWithFrame:NSMakeRect(24, 252, 72, 72)];
    logo.image = [self.bundle imageForResource:@"mysql_logo"];
    logo.imageScaling = NSImageScaleProportionallyUpOrDown;
    [view addSubview:logo];

    NSTextField *title = [self makeLabel:@"MySQL 数据库服务" bold:YES size:20
                                   frame:NSMakeRect(112, 296, 400, 28)];
    [view addSubview:title];

    NSTextField *subtitle = [self makeLabel:@"通过系统设置面板启动、停止或重启本机的 MySQL 服务。"
                                            bold:NO size:11 frame:NSMakeRect(113, 276, 520, 16)];
    subtitle.textColor = NSColor.secondaryLabelColor;
    [view addSubview:subtitle];

    NSTextField *statusTitle = [self makeLabel:@"运行状态：" bold:YES size:13
                                         frame:NSMakeRect(113, 236, 70, 20)];
    [view addSubview:statusTitle];

    _statusLabel = [self makeLabel:@"检测中…" bold:NO size:13
                             frame:NSMakeRect(187, 236, 300, 20)];
    [view addSubview:_statusLabel];

    _versionLabel = [self makeLabel:@"" bold:NO size:11
                              frame:NSMakeRect(113, 214, 520, 16)];
    _versionLabel.textColor = NSColor.secondaryLabelColor;
    [view addSubview:_versionLabel];

    NSTextField *switchTitle = [self makeLabel:@"MySQL 服务" bold:YES size:13
                                         frame:NSMakeRect(24, 168, 120, 22)];
    [view addSubview:switchTitle];

    _serviceSwitch = [[NSSwitch alloc] initWithFrame:NSMakeRect(150, 166, 60, 26)];
    _serviceSwitch.target = self;
    _serviceSwitch.action = @selector(toggleService:);
    [view addSubview:_serviceSwitch];

    _restartButton = [[NSButton alloc] initWithFrame:NSMakeRect(230, 164, 96, 28)];
    _restartButton.title = @"重启服务";
    _restartButton.bezelStyle = NSBezelStyleRounded;
    _restartButton.target = self;
    _restartButton.action = @selector(restartService:);
    [view addSubview:_restartButton];

    NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(24, 140, 620, 1)];
    separator.boxType = NSBoxSeparator;
    [view addSubview:separator];

    NSTextField *pathTitle = [self makeLabel:@"MySQL 安装位置：" bold:YES size:13
                                       frame:NSMakeRect(24, 100, 120, 20)];
    [view addSubview:pathTitle];

    _pathField = [[NSTextField alloc] initWithFrame:NSMakeRect(24, 68, 500, 24)];
    _pathField.placeholderString = @"/usr/local/mysql";
    _pathField.stringValue = [self installPath];
    _pathField.delegate = self;
    [view addSubview:_pathField];

    NSButton *browse = [[NSButton alloc] initWithFrame:NSMakeRect(534, 66, 110, 28)];
    browse.title = @"浏览…";
    browse.bezelStyle = NSBezelStyleRounded;
    browse.target = self;
    browse.action = @selector(browsePath:);
    [view addSubview:browse];

    NSString *hint = [self hasLaunchDaemon]
        ? @"本机 MySQL 由 launchd 管理（com.oracle.oss.mysql.mysqld），面板通过 launchctl 控制服务。"
        : @"将使用 <安装位置>/support-files/mysql.server 管理服务；执行 start/stop/restart 需要管理员权限。";
    _hintLabel = [self makeLabel:hint bold:NO size:10 frame:NSMakeRect(24, 30, 620, 14)];
    _hintLabel.textColor = NSColor.secondaryLabelColor;
    [view addSubview:_hintLabel];

    [self setMainView:view];
    [self setInitialKeyView:_serviceSwitch];
    [self setFirstKeyView:_serviceSwitch];
    [self setLastKeyView:browse];
    [self mainViewDidLoad];
    return view;
}

- (void)mainViewDidLoad
{
    [self refreshVersion];
    [self refreshStatus];
}

- (void)didSelect
{
    [self refreshVersion];
    [self refreshStatus];
    _statusTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                    target:self
                                                  selector:@selector(refreshStatus)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)willUnselect
{
    [_statusTimer invalidate];
    _statusTimer = nil;
}

- (NSTextField *)makeLabel:(NSString *)text bold:(BOOL)bold size:(CGFloat)size frame:(NSRect)frame
{
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = text;
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    label.bezeled = NO;
    label.editable = NO;
    label.selectable = NO;
    label.drawsBackground = NO;
    return label;
}

#pragma mark - 安装路径

- (NSString *)installPath
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultsSuite];
    NSString *path = [defaults stringForKey:kInstallPathKey];
    return path.length ? path : kDefaultPath;
}

- (void)saveInstallPath:(NSString *)path
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kDefaultsSuite];
    [defaults setObject:path forKey:kInstallPathKey];
}

- (void)browsePath:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.prompt = @"选择";
    panel.directoryURL = [NSURL fileURLWithPath:[self installPath]];
    NSWindow *window = self.mainView.window;
    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URLs.count) {
            NSString *path = panel.URLs.firstObject.path;
            self->_pathField.stringValue = path;
            [self saveInstallPath:path];
            [self refreshVersion];
        }
    }];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if (notification.object == _pathField) {
        NSString *path = [_pathField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (path.length == 0) {
            path = kDefaultPath;
            _pathField.stringValue = path;
        }
        [self saveInstallPath:path];
        [self refreshVersion];
    }
}

#pragma mark - 状态与版本

- (BOOL)hasLaunchDaemon
{
    return [NSFileManager.defaultManager fileExistsAtPath:kLaunchDaemonPlist];
}

- (BOOL)isServerRunning
{
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/pgrep";
    task.arguments = @[@"-x", @"mysqld"];
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        return NO;
    }
    return task.terminationStatus == 0;
}

- (void)refreshStatus
{
    BOOL running = [self isServerRunning];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (running) {
            self->_statusLabel.stringValue = @"● 正在运行";
            self->_statusLabel.textColor = [NSColor colorWithRed:0.15 green:0.65 blue:0.25 alpha:1.0];
        } else {
            self->_statusLabel.stringValue = @"● 已停止";
            self->_statusLabel.textColor = NSColor.systemRedColor;
        }
        self->_updatingSwitch = YES;
        self->_serviceSwitch.state = running ? NSControlStateValueOn : NSControlStateValueOff;
        self->_updatingSwitch = NO;
        self->_serviceSwitch.enabled = !self->_busy;
        self->_restartButton.enabled = running && !self->_busy;
    });
}

- (void)refreshVersion
{
    NSString *path = [[self installPath] stringByAppendingPathComponent:@"bin/mysqld"];
    if (![NSFileManager.defaultManager isExecutableFileAtPath:path]) {
        _versionLabel.stringValue = @"未在所选位置找到 MySQL（bin/mysqld 不存在），请检查安装位置。";
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = path;
        task.arguments = @[@"--version"];
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = pipe;
        NSString *text = @"";
        @try {
            [task launch];
            NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
            [task waitUntilExit];
            text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                    stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        } @catch (NSException *e) {}
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_versionLabel.stringValue = text.length ? [@"版本信息：" stringByAppendingString:text] : @"无法获取版本信息。";
        });
    });
}

#pragma mark - 服务控制

- (void)toggleService:(id)sender
{
    if (_updatingSwitch) return;
    [self runAction:_serviceSwitch.state == NSControlStateValueOn ? @"start" : @"stop"];
}

- (void)restartService:(id)sender
{
    [self runAction:@"restart"];
}

// 返回需要依次执行的命令列表（不含 sudo）
- (NSArray<NSArray<NSString *> *> *)commandsForAction:(NSString *)action
{
    if ([self hasLaunchDaemon]) {
        // 本机 MySQL 由 launchd 管理。mysql.server 与 launchd 的 pid 文件路径不一致
        // 且 KeepAlive 会拉起进程，必须用 launchctl 控制。
        if ([action isEqualToString:@"start"]) {
            return @[ @[@"/bin/launchctl", @"bootstrap", @"system", kLaunchDaemonPlist],
                      @[@"/bin/launchctl", @"kickstart", kLaunchDaemonLabel] ];
        } else if ([action isEqualToString:@"stop"]) {
            return @[ @[@"/bin/launchctl", @"bootout", kLaunchDaemonLabel] ];
        } else {
            return @[ @[@"/bin/launchctl", @"kickstart", @"-k", kLaunchDaemonLabel] ];
        }
    }
    NSString *script = [[self installPath] stringByAppendingPathComponent:@"support-files/mysql.server"];
    return @[ @[script, action] ];
}

// sudo -n 执行单条命令。passwordRequired=YES 表示需要密码（未配置免密）。
- (BOOL)runWithSudo:(NSArray<NSString *> *)arguments
              error:(NSString **)error
   passwordRequired:(BOOL *)passwordRequired
{
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/sudo";
    task.arguments = [@[@"-n"] arrayByAddingObjectsFromArray:arguments];
    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = errPipe;
    @try {
        [task launch];
    } @catch (NSException *e) {
        if (error) *error = e.reason;
        return NO;
    }
    NSData *outData = [outPipe.fileHandleForReading readDataToEndOfFile];
    NSData *errData = [errPipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];

    NSString *output = [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @""
                        stringByAppendingString:[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] ?: @""];
    if (task.terminationStatus != 0) {
        if ([output containsString:@"a password is required"]) {
            if (passwordRequired) *passwordRequired = YES;
        } else if (error) {
            *error = output.length ? output : [NSString stringWithFormat:@"退出码 %d", task.terminationStatus];
        }
        return NO;
    }
    return YES;
}

// 弹系统密码框执行（未配置免密时的回退方案）
- (NSDictionary *)runWithAdminPrompt:(NSArray<NSArray<NSString *> *> *)commands
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSArray<NSString *> *cmd in commands) {
        NSMutableArray *quoted = [NSMutableArray array];
        for (NSString *arg in cmd) {
            [quoted addObject:[NSString stringWithFormat:@"'%@'", [arg stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]]];
        }
        [parts addObject:[quoted componentsJoinedByString:@" "]];
    }
    NSMutableString *shell = [[parts componentsJoinedByString:@" && "] mutableCopy];
    [shell replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, shell.length)];
    [shell replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, shell.length)];
    NSString *source = [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", shell];
    NSDictionary *errorInfo = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    [script executeAndReturnError:&errorInfo];
    return errorInfo;
}

- (void)runAction:(NSString *)action
{
    if (_busy) return;

    if (![self hasLaunchDaemon]) {
        NSString *script = [[self installPath] stringByAppendingPathComponent:@"support-files/mysql.server"];
        if (![NSFileManager.defaultManager fileExistsAtPath:script]) {
            [self showError:[NSString stringWithFormat:@"找不到管理脚本：\n%@\n\n请在下方设置正确的 MySQL 安装位置。", script]];
            [self refreshStatus];
            return;
        }
    }

    _busy = YES;
    _serviceSwitch.enabled = NO;
    _restartButton.enabled = NO;
    _statusLabel.stringValue = @"● 正在执行…";
    _statusLabel.textColor = NSColor.systemOrangeColor;

    NSArray<NSArray<NSString *> *> *commands = [self commandsForAction:action];
    BOOL wantRunning = ![action isEqualToString:@"stop"];
    BOOL useLaunchd = [self hasLaunchDaemon];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *failure = nil;
        BOOL needPassword = NO;
        BOOL canceled = NO;

        for (NSArray<NSString *> *cmd in commands) {
            NSString *err = nil;
            BOOL pwReq = NO;
            // launchctl 对“已加载/未加载”状态的良性报错直接忽略，以最终状态轮询为准
            [self runWithSudo:cmd error:&err passwordRequired:&pwReq];
            if (pwReq) { needPassword = YES; break; }
            if (err && !useLaunchd) failure = err;
        }

        if (needPassword) {
            NSDictionary *errorInfo = [self runWithAdminPrompt:commands];
            if (errorInfo) {
                NSNumber *code = errorInfo[NSAppleScriptErrorNumber];
                if (code.integerValue == -128) {
                    canceled = YES; // 用户取消输入密码，保持静默
                } else {
                    failure = errorInfo[NSAppleScriptErrorMessage] ?: @"未知错误";
                }
            }
        }

        // 轮询最终状态（mysqld 停止可能需要几秒），最多约 25 秒
        BOOL reached = NO;
        if (failure == nil && !canceled) {
            for (int i = 0; i < 25; i++) {
                [NSThread sleepForTimeInterval:1.0];
                if ([self isServerRunning] == wantRunning) { reached = YES; break; }
            }
        }

        NSString *finalError = failure;
        if (finalError == nil && !canceled && !reached) {
            finalError = @"命令已执行，但服务状态未按预期改变。";
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_busy = NO;
            if (finalError) {
                [self showError:[NSString stringWithFormat:@"执行失败：\n%@\n\n提示：运行一次项目目录下的 setup_sudoers.sh 可配置免密管理。", finalError]];
            }
            [self refreshStatus];
        });
    });
}

- (void)showError:(NSString *)message
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"MySQL 控制面板";
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"好"];
    [alert beginSheetModalForWindow:self.mainView.window completionHandler:nil];
}

@end
