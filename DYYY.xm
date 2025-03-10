//
//  DYYY
//
//  Copyright (c) 2024 huami. All rights reserved.
//  Channel: @huamidev
//  Created on: 2024/10/04
//
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CityManager.h"

// 添加日志管理器
@interface DYYYLogger : NSObject
@property (nonatomic, strong) NSFileHandle *logFileHandle;
@property (nonatomic, copy) NSString *logFilePath;
+ (instancetype)sharedInstance;
- (void)logEvent:(NSString *)event;
- (void)logViewHierarchy:(UIView *)view withTitle:(NSString *)title;
- (void)logRequest:(NSURLRequest *)request;
@end

@implementation DYYYLogger

+ (instancetype)sharedInstance {
    static DYYYLogger *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DYYYLogger alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // 创建日志文件
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        self.logFilePath = [documentsPath stringByAppendingPathComponent:@"dyyy_debug.log"];
        
        // 创建或清空日志文件
        NSString *initialLog = [NSString stringWithFormat:@"=== DYYY Debug Log Start at %@ ===\n", 
            [NSDateFormatter localizedStringFromDate:[NSDate date] 
                                        dateStyle:NSDateFormatterMediumStyle 
                                        timeStyle:NSDateFormatterMediumStyle]];
        
        NSError *error = nil;
        [initialLog writeToFile:self.logFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            NSLog(@"[DYYY] Failed to create log file: %@", error);
        } else {
            NSLog(@"[DYYY] Log file created at: %@", self.logFilePath);
        }
        
        // 打开文件句柄用于追加写入
        self.logFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.logFilePath];
        [self.logFileHandle seekToEndOfFile];
        
        // 写入初始测试日志
        [self logEvent:@"Logger initialized successfully"];
    }
    return self;
}

- (void)logEvent:(NSString *)event {
    @synchronized (self) {
        NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                           dateStyle:NSDateFormatterNoStyle
                                                           timeStyle:NSDateFormatterMediumStyle];
        NSString *logEntry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, event];
        
        // 同时输出到控制台和文件
        NSLog(@"[DYYY] %@", logEntry);
        
        @try {
            [self.logFileHandle writeData:[logEntry dataUsingEncoding:NSUTF8StringEncoding]];
            [self.logFileHandle synchronizeFile];
        } @catch (NSException *exception) {
            NSLog(@"[DYYY] Failed to write log: %@", exception);
        }
    }
}

- (void)logViewHierarchy:(UIView *)view withTitle:(NSString *)title {
    @synchronized (self) {
        NSMutableString *hierarchy = [NSMutableString stringWithFormat:@"\n=== %@ ===\n", title];
        [self dumpView:view withIndent:0 toString:hierarchy];
        [self logEvent:hierarchy];
    }
}

- (void)logRequest:(NSURLRequest *)request {
    @synchronized (self) {
        NSMutableString *requestInfo = [NSMutableString stringWithString:@"\n=== Network Request ===\n"];
        [requestInfo appendFormat:@"URL: %@\n", request.URL.absoluteString];
        [requestInfo appendFormat:@"Method: %@\n", request.HTTPMethod];
        [requestInfo appendFormat:@"Headers: %@\n", request.allHTTPHeaderFields];
        
        if (request.HTTPBody) {
            NSString *bodyString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
            [requestInfo appendFormat:@"Body: %@\n", bodyString];
        }
        
        [self logEvent:requestInfo];
    }
}

- (void)dumpView:(UIView *)view withIndent:(int)indent toString:(NSMutableString *)output {
    NSString *indentString = [@"" stringByPaddingToLength:indent withString:@"  " startingAtIndex:0];
    NSString *className = NSStringFromClass([view class]);
    NSString *frame = NSStringFromCGRect(view.frame);
    NSString *accessibilityLabel = view.accessibilityLabel ?: @"";
    
    [output appendFormat:@"%@%@ (Frame: %@, Label: %@)\n", 
        indentString, className, frame, accessibilityLabel];
    
    for (UIView *subview in view.subviews) {
        [self dumpView:subview withIndent:indent + 1 toString:output];
    }
}

- (void)dealloc {
    [self.logFileHandle closeFile];
}

@end

// 添加获取主窗口的辅助方法
static UIWindow* GetMainWindow(void) {
    UIWindow *window = nil;
    
    if (@available(iOS 15.0, *)) {
        NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            window = w;
                            break;
                        }
                    }
                    if (!window) {
                        window = windowScene.windows.firstObject;
                    }
                    break;
                }
            }
        }
    } else if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (!window) {
                    window = windowScene.windows.firstObject;
                }
                if (window) break;
            }
        }
    }
    
    // 如果上面的方法都没找到窗口，使用传统方法
    if (!window) {
        window = [[UIApplication sharedApplication].windows firstObject];
    }
    
    return window;
}

// 添加按钮信息收集器
@interface DYYYButtonInfo : NSObject
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *accessibilityLabel;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) CGRect frame;
+ (instancetype)infoWithClass:(NSString *)className label:(NSString *)label title:(NSString *)title frame:(CGRect)frame;
@end

@implementation DYYYButtonInfo
+ (instancetype)infoWithClass:(NSString *)className label:(NSString *)label title:(NSString *)title frame:(CGRect)frame {
    DYYYButtonInfo *info = [[DYYYButtonInfo alloc] init];
    info.className = className;
    info.accessibilityLabel = label;
    info.title = title;
    info.frame = frame;
    return info;
}
@end

// 添加按钮管理器
@interface DYYYButtonManager : NSObject
@property (nonatomic, strong) NSMutableSet<DYYYButtonInfo *> *buttonInfos;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *buttonSettings;
+ (instancetype)sharedInstance;
- (void)addButtonInfo:(DYYYButtonInfo *)info;
- (void)generateSettings;
@end

@implementation DYYYButtonManager

+ (instancetype)sharedInstance {
    static DYYYButtonManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DYYYButtonManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.buttonInfos = [NSMutableSet set];
        self.buttonSettings = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addButtonInfo:(DYYYButtonInfo *)info {
    if (!info.accessibilityLabel.length) return;
    
    @synchronized (self.buttonInfos) {
        [self.buttonInfos addObject:info];
        
        // 自动生成设置键
        NSString *settingKey = [NSString stringWithFormat:@"DYYYHide%@Button", 
            [info.accessibilityLabel stringByReplacingOccurrencesOfString:@" " withString:@""]];
        self.buttonSettings[info.accessibilityLabel] = settingKey;
        
        // 延迟执行设置生成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self generateSettings];
        });
    }
}

- (void)generateSettings {
    static BOOL hasGenerated = NO;
    if (hasGenerated) return;
    hasGenerated = YES;
    
    // 生成设置项
    NSMutableArray *settingItems = [NSMutableArray array];
    for (DYYYButtonInfo *info in self.buttonInfos) {
        NSString *settingKey = self.buttonSettings[info.accessibilityLabel];
        if (!settingKey) continue;
        
        [settingItems addObject:@{
            @"title": [NSString stringWithFormat:@"隐藏%@", info.accessibilityLabel],
            @"key": settingKey
        }];
    }
    
    // 保存设置项到 UserDefaults
    [[NSUserDefaults standardUserDefaults] setObject:settingItems forKey:@"DYYYAutoGeneratedSettings"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 发送通知更新设置界面
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DYYYSettingsUpdated" 
                                                      object:nil 
                                                    userInfo:@{@"settings": settingItems}];
}

@end

@interface AWENormalModeTabBarGeneralButton : UIButton
@end

@interface AWENormalModeTabBarBadgeContainerView : UIView

@end

@interface AWEFeedContainerContentView : UIView
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@end

@interface AWELeftSideBarEntranceView : UIView
@end

@interface AWEDanmakuContentLabel : UILabel
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor;
@end

@interface AWELandscapeFeedEntryView : UIView
@end

@interface AWEPlayInteractionViewController : UIViewController
@property (nonatomic, strong) UIView *view;
@end

@interface UIView (Transparency)
- (UIViewController *)firstAvailableUIViewController;
@end

@interface AWEFeedVideoButton : UIButton
@end

@interface AWEMusicCoverButton : UIButton
@end

@interface AWEDoupackButton : UIButton
@end

@interface AWEAwemePlayVideoViewController : UIViewController

- (void)setVideoControllerPlaybackRate:(double)arg0;

@end

@interface AWEDanmakuItemTextInfo : NSObject
- (void)setDanmakuTextColor:(id)arg1;
- (UIColor *)colorFromHexStringForTextInfo:(NSString *)hexString;
@end

@interface AWECommentMiniEmoticonPanelView : UIView

@end

@interface AWEBaseElementView : UIView

@end

@interface AWETextViewInternal : UITextView

@end

@interface AWECommentPublishGuidanceView : UIView

@end

@interface AWEPlayInteractionFollowPromptView : UIView

@end

@interface AWENormalModeTabBarTextView : UIView

@end

@interface AWEPlayInteractionProgressController : UIView
//- (void)writeLog:(NSString *)log;
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@end

@interface AWEAdAvatarView : UIView

@end

@interface AWENormalModeTabBar : UIView

@end

@interface AWEPlayInteractionListenFeedView : UIView

@end

@interface AWEFeedLiveMarkView : UIView

@end

@interface AWEAwemeModel : NSObject
@property (nonatomic, copy) NSString *ipAttribution;
@property (nonatomic, copy) NSString *cityCode;
@end

@interface AWEPlayInteractionTimestampElement : UIView
@property (nonatomic, strong) AWEAwemeModel *model;
@end

@interface AWEPlayInteractionDoupackElement : UIView
@end

@interface AWEDoupackContainerView : UIView
@end

@interface AWEPlayInteractionDoupackView : UIView
@end

@interface AWEDoupackIconView : UIView
@end

// 添加调试信息视图控制器
@interface DYYYDebugViewController : UIViewController
@property (nonatomic, strong) UITextView *debugTextView;
@property (nonatomic, strong) NSMutableString *debugInfo;
+ (instancetype)sharedInstance;
+ (UIWindow *)mainWindow;
- (void)appendDebugInfo:(NSString *)info;
- (void)show;
@end

@implementation DYYYDebugViewController

+ (UIWindow *)mainWindow {
    return GetMainWindow();
}

+ (instancetype)sharedInstance {
    static DYYYDebugViewController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DYYYDebugViewController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.debugInfo = [NSMutableString string];
        
        // 设置视图控制器属性
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        if (@available(iOS 13.0, *)) {
            self.modalInPresentation = YES;
        }
        
        // 创建文本视图
        self.debugTextView = [[UITextView alloc] init];
        self.debugTextView.editable = NO;
        self.debugTextView.font = [UIFont systemFontOfSize:14];
        self.debugTextView.backgroundColor = [UIColor blackColor];
        self.debugTextView.textColor = [UIColor whiteColor];
        
        // 创建关闭按钮
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(dismissDebugView) forControlEvents:UIControlEventTouchUpInside];
        
        // 创建复制按钮
        UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [copyButton setTitle:@"复制" forState:UIControlStateNormal];
        [copyButton addTarget:self action:@selector(copyDebugInfo) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加视图
        [self.view addSubview:self.debugTextView];
        [self.view addSubview:closeButton];
        [self.view addSubview:copyButton];
        
        // 设置约束
        self.debugTextView.translatesAutoresizingMaskIntoConstraints = NO;
        closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        copyButton.translatesAutoresizingMaskIntoConstraints = NO;
        
        [NSLayoutConstraint activateConstraints:@[
            [self.debugTextView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:50],
            [self.debugTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
            [self.debugTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
            [self.debugTextView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-50],
            
            [closeButton.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
            [closeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
            
            [copyButton.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
            [copyButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        ]];
        
        self.view.backgroundColor = [UIColor blackColor];
    }
    return self;
}

- (void)appendDebugInfo:(NSString *)info {
    [self.debugInfo appendString:info];
    [self.debugInfo appendString:@"\n"];
    self.debugTextView.text = self.debugInfo;
    [self.debugTextView scrollRangeToVisible:NSMakeRange(self.debugTextView.text.length, 0)];
}

- (void)show {
    UIWindow *mainWindow = GetMainWindow();
    UIViewController *topVC = mainWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    [topVC presentViewController:self animated:YES completion:nil];
}

- (void)dismissDebugView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyDebugInfo {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.debugInfo;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"成功" 
                                                                  message:@"调试信息已复制到剪贴板" 
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

%hook AWEAwemePlayVideoViewController

- (void)setIsAutoPlay:(BOOL)arg0 {
    float defaultSpeed = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYDefaultSpeed"];
    
    if (defaultSpeed > 0 && defaultSpeed != 1) {
        [self setVideoControllerPlaybackRate:defaultSpeed];
    }
    
    %orig(arg0);
}

%end


%hook AWENormalModeTabBarGeneralPlusButton
+ (id)button {
    BOOL isHiddenJia = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenJia"];
    if (isHiddenJia) {
        return nil;
    }
    return %orig;
}
%end

%hook AWEFeedContainerContentView
- (void)setAlpha:(CGFloat)alpha {
    NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYtopbartransparent"];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnablePure"]) {
        %orig(0.0);
        
        static dispatch_source_t timer = nil;
        static int attempts = 0;
        
        if (timer) {
            dispatch_source_cancel(timer);
            timer = nil;
        }
        
        void (^tryFindAndSetPureMode)(void) = ^{
            Class FeedTableVC = NSClassFromString(@"AWEFeedTableViewController");
            UIViewController *feedVC = nil;
            
            UIWindow *mainWindow = [DYYYDebugViewController mainWindow];
            if (mainWindow && mainWindow.rootViewController) {
                feedVC = [self findViewController:mainWindow.rootViewController ofClass:FeedTableVC];
                if (feedVC) {
                    [feedVC setValue:@YES forKey:@"pureMode"];
                    if (timer) {
                        dispatch_source_cancel(timer);
                        timer = nil;
                    }
                    attempts = 0;
                    return;
                }
            }
            
            attempts++;
            if (attempts >= 10) {
                if (timer) {
                    dispatch_source_cancel(timer);
                    timer = nil;
                }
                attempts = 0;
            }
        };
        
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(timer, tryFindAndSetPureMode);
        dispatch_resume(timer);
        
        tryFindAndSetPureMode();
        return;
    }
    
    if (transparentValue && transparentValue.length > 0) {
        CGFloat alphaValue = [transparentValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            %orig(alphaValue);
        } else {
            %orig(1.0);
        }
    } else {
        %orig(1.0);
    }
}

%new
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass {
    if (!vc) return nil;
    if ([vc isKindOfClass:targetClass]) return vc;
    
    for (UIViewController *childVC in vc.childViewControllers) {
        UIViewController *found = [self findViewController:childVC ofClass:targetClass];
        if (found) return found;
    }
    
    return [self findViewController:vc.presentedViewController ofClass:targetClass];
}
%end

%hook AWEDanmakuContentLabel
- (void)setTextColor:(UIColor *)textColor {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDanmuColor"]) {
        NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];
        
        if ([danmuColor.lowercaseString isEqualToString:@"random"] || [danmuColor.lowercaseString isEqualToString:@"#random"]) {
            textColor = [UIColor colorWithRed:(arc4random_uniform(256)) / 255.0
                                        green:(arc4random_uniform(256)) / 255.0
                                         blue:(arc4random_uniform(256)) / 255.0
                                        alpha:CGColorGetAlpha(textColor.CGColor)];
            self.layer.shadowOffset = CGSizeZero;
            self.layer.shadowOpacity = 0.0;
        } else if ([danmuColor hasPrefix:@"#"]) {
            textColor = [self colorFromHexString:danmuColor baseColor:textColor];
            self.layer.shadowOffset = CGSizeZero;
            self.layer.shadowOpacity = 0.0;
        } else {
            textColor = [self colorFromHexString:@"#FFFFFF" baseColor:textColor];
        }
    }

    %orig(textColor);
}

%new
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor {
    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }
    if ([hexString length] != 6) {
        return [baseColor colorWithAlphaComponent:1];
    }
    unsigned int red, green, blue;
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    return [UIColor colorWithRed:(red / 255.0) green:(green / 255.0) blue:(blue / 255.0) alpha:CGColorGetAlpha(baseColor.CGColor)];
}
%end

%hook AWEDanmakuItemTextInfo
- (void)setDanmakuTextColor:(id)arg1 {
//    NSLog(@"Original Color: %@", arg1);
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDanmuColor"]) {
        NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];
        
        if ([danmuColor.lowercaseString isEqualToString:@"random"] || [danmuColor.lowercaseString isEqualToString:@"#random"]) {
            arg1 = [UIColor colorWithRed:(arc4random_uniform(256)) / 255.0
                                   green:(arc4random_uniform(256)) / 255.0
                                    blue:(arc4random_uniform(256)) / 255.0
                                   alpha:1.0];
//            NSLog(@"Random Color: %@", arg1);
        } else if ([danmuColor hasPrefix:@"#"]) {
            arg1 = [self colorFromHexStringForTextInfo:danmuColor];
//            NSLog(@"Custom Hex Color: %@", arg1);
        } else {
            arg1 = [self colorFromHexStringForTextInfo:@"#FFFFFF"];
//            NSLog(@"Default White Color: %@", arg1);
        }
    }

    %orig(arg1);
}

%new
- (UIColor *)colorFromHexStringForTextInfo:(NSString *)hexString {
    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }
    if ([hexString length] != 6) {
        return [UIColor whiteColor];
    }
    unsigned int red, green, blue;
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    return [UIColor colorWithRed:(red / 255.0) green:(green / 255.0) blue:(blue / 255.0) alpha:1.0];
}
%end

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig(frame);
    if (window) {
        UILongPressGestureRecognizer *doubleFingerLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleFingerLongPressGesture:)];
        doubleFingerLongPressGesture.numberOfTouchesRequired = 2;
        [window addGestureRecognizer:doubleFingerLongPressGesture];
    }
    return window;
}

%new
- (void)handleDoubleFingerLongPressGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *rootViewController = self.rootViewController;
        if (rootViewController) {
            UIViewController *settingVC = [[NSClassFromString(@"DYYYSettingViewController") alloc] init];
            
            if (settingVC) {
                settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
                
                UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
                [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
                closeButton.translatesAutoresizingMaskIntoConstraints = NO;
                
                [settingVC.view addSubview:closeButton];
                
                [NSLayoutConstraint activateConstraints:@[
                    [closeButton.trailingAnchor constraintEqualToAnchor:settingVC.view.trailingAnchor constant:-10],
                    [closeButton.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:40],
                    [closeButton.widthAnchor constraintEqualToConstant:80],
                    [closeButton.heightAnchor constraintEqualToConstant:40]
                ]];
                
                [closeButton addTarget:self action:@selector(closeSettings:) forControlEvents:UIControlEventTouchUpInside];
                
                [rootViewController presentViewController:settingVC animated:YES completion:nil];
            }
        }
    }
}
%new
- (void)closeSettings:(UIButton *)button {
    [button.superview.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}
%end

%hook AWEFeedLiveMarkView
- (void)setHidden:(BOOL)hidden {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAvatarButton"]) {
        hidden = YES;
    }

    %orig(hidden);
}
%end

%hook AWELongVideoControlModel
- (bool)allowDownload {
    return YES;
}
%end

%hook AWELongVideoControlModel
- (long long)preventDownloadType {
    return 0;
}
%end

%hook AWELandscapeFeedEntryView
- (void)setHidden:(BOOL)hidden {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenEntry"]) {
        hidden = YES;
    }
    
    %orig(hidden);
}
%end

%hook UIView

- (void)setAlpha:(CGFloat)alpha {
    UIViewController *vc = [self firstAvailableUIViewController];
    
    if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)] && alpha > 0) {
        NSString *transparentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
        if (transparentValue.length > 0) {
            CGFloat alphaValue = transparentValue.floatValue;
            if (alphaValue >= 0.0 && alphaValue <= 1.0) {
                %orig(alphaValue);
                return;
            }
        }
    }
    %orig;
}

%new
- (UIViewController *)firstAvailableUIViewController {
    UIResponder *responder = [self nextResponder];
    while (responder != nil) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

%end

%hook AWEAwemeModel

- (void)setIsAds:(BOOL)isAds {
    %orig(NO);
}

%end

%hook AWENormalModeTabBarBadgeContainerView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenBottomDot"]) {
        for (UIView *subview in [self subviews]) {
            if ([subview isKindOfClass:NSClassFromString(@"DUXBadge")]) {
                [subview setHidden:YES];
            }
        }
    }
}

%end

%hook AWELeftSideBarEntranceView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenSidebarDot"]) {
        for (UIView *subview in [self subviews]) {
            if ([subview isKindOfClass:NSClassFromString(@"DUXBadge")]) {
                subview.hidden = YES;
            }
        }
    }
}

%end

%hook AWEFeedVideoButton

- (void)layoutSubviews {
    %orig;
    
    // 添加调试日志
    NSLog(@"[DYYY Debug] Button Class: %@", NSStringFromClass([self class]));
    NSLog(@"[DYYY Debug] Accessibility Label: %@", self.accessibilityLabel);
    NSLog(@"[DYYY Debug] Title: %@", [self titleForState:UIControlStateNormal]);
    
    BOOL hideLikeButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLikeButton"];
    BOOL hideCommentButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentButton"];
    BOOL hideCollectButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCollectButton"];
    BOOL hideShareButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShareButton"];
    BOOL hideDoupackButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"];

    NSString *accessibilityLabel = self.accessibilityLabel;

//    NSLog(@"Accessibility Label: %@", accessibilityLabel);

    if ([accessibilityLabel isEqualToString:@"豆包"]) {
        if (hideDoupackButton) {
            [self removeFromSuperview];
            return;
        }
    } else if ([accessibilityLabel isEqualToString:@"点赞"]) {
        if (hideLikeButton) {
            [self removeFromSuperview];
            return;
        }
    } else if ([accessibilityLabel isEqualToString:@"评论"]) {
        if (hideCommentButton) {
            [self removeFromSuperview];
            return;
        }
    } else if ([accessibilityLabel isEqualToString:@"分享"]) {
        if (hideShareButton) {
            [self removeFromSuperview];
            return;
        }
    } else if ([accessibilityLabel isEqualToString:@"收藏"]) {
        if (hideCollectButton) {
            [self removeFromSuperview];
            return;
        }
    }

}

%end

%hook AWEMusicCoverButton

- (void)layoutSubviews {
    %orig;

    BOOL hideMusicButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMusicButton"];

    NSString *accessibilityLabel = self.accessibilityLabel;

//    NSLog(@"Accessibility Label: %@", accessibilityLabel);

    if ([accessibilityLabel isEqualToString:@"音乐详情"]) {
        if (hideMusicButton) {
            [self removeFromSuperview];
            return;
        }
    }
}

%end

%hook AWEPlayInteractionListenFeedView
- (void)layoutSubviews {
    %orig;
    BOOL hideMusicButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMusicButton"];
    if (hideMusicButton) {
        [self removeFromSuperview];
        return;
    }
}
%end

%hook AWEPlayInteractionFollowPromptView

- (void)layoutSubviews {
    %orig;

    BOOL hideAvatarButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAvatarButton"];

    NSString *accessibilityLabel = self.accessibilityLabel;

//    NSLog(@"Accessibility Label: %@", accessibilityLabel);

    if ([accessibilityLabel isEqualToString:@"关注"]) {
        if (hideAvatarButton) {
            [self removeFromSuperview];
            return;
        }
    }
}

%end

%hook AWEAdAvatarView

- (void)layoutSubviews {
    %orig;

    BOOL hideAvatarButton = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAvatarButton"];
    if (hideAvatarButton) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWENormalModeTabBar

- (void)layoutSubviews {
    %orig;

    // 获取用户设置
    BOOL hideShop = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShopButton"];
    BOOL hideMsg = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMessageButton"];
    BOOL hideFri = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideFriendsButton"];
    
    NSMutableArray *visibleButtons = [NSMutableArray array];
    Class generalButtonClass = %c(AWENormalModeTabBarGeneralButton);
    Class plusButtonClass = %c(AWENormalModeTabBarGeneralPlusButton);
    
    // 遍历所有子视图处理隐藏逻辑
    for (UIView *subview in self.subviews) {
        if (![subview isKindOfClass:generalButtonClass] && ![subview isKindOfClass:plusButtonClass]) continue;
        
        NSString *label = subview.accessibilityLabel;
        BOOL shouldHide = NO;
        
        if ([label isEqualToString:@"商城"]) {
            shouldHide = hideShop;
        } else if ([label containsString:@"消息"]) {
            shouldHide = hideMsg;
        } else if ([label containsString:@"朋友"]) {
            shouldHide = hideFri;
        }
        
        if (!shouldHide) {
            [visibleButtons addObject:subview];
        } else {
            [subview removeFromSuperview];
        }
    }

    [visibleButtons sortUsingComparator:^NSComparisonResult(UIView* a, UIView* b) {
        return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];
    }];

    CGFloat totalWidth = self.bounds.size.width;
    CGFloat buttonWidth = totalWidth / visibleButtons.count;
    
    for (NSInteger i = 0; i < visibleButtons.count; i++) {
        UIView *button = visibleButtons[i];
        button.frame = CGRectMake(i * buttonWidth, button.frame.origin.y, buttonWidth, button.frame.size.height);
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenBottomBg"]) {
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class]) {  // 确保是真正的UIView而不是子类
                BOOL hasImageView = NO;
                for (UIView *childView in subview.subviews) {
                    if ([childView isKindOfClass:[UIImageView class]]) {
                        hasImageView = YES;
                        break;
                    }
                }
                
                if (hasImageView) {
                    subview.hidden = YES;
                    break;  // 只隐藏第一个符合条件的视图
                }
            }
        }
    }
}

%end

%hook UITextInputTraits
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        %orig(UIKeyboardAppearanceDark);
    }else {
        %orig;
    }
}
%end

%hook AWECommentMiniEmoticonPanelView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UICollectionView class]]) {
                subview.backgroundColor = [UIColor colorWithRed:115/255.0 green:115/255.0 blue:115/255.0 alpha:1.0];
            }
        }
    }
}
%end

%hook AWECommentPublishGuidanceView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UICollectionView class]]) {
                subview.backgroundColor = [UIColor colorWithRed:115/255.0 green:115/255.0 blue:115/255.0 alpha:1.0];
            }
        }
    }
}
%end

%hook UIView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        for (UIView *subview in self.subviews) {
            
            if ([subview isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer")]) {
                for (UIView *innerSubview in subview.subviews) {
                    if ([innerSubview isKindOfClass:[UIView class]]) {
                        innerSubview.backgroundColor = [UIColor colorWithRed:31/255.0 green:33/255.0 blue:35/255.0 alpha:1.0];
                        break;
                    }
                }
            }
            if ([subview isKindOfClass:NSClassFromString(@"AWEIMEmoticonPanelBoxView")]) {
                subview.backgroundColor = [UIColor colorWithRed:33/255.0 green:33/255.0 blue:33/255.0 alpha:1.0];
            }
            
        }
    }
}
%end

%hook UILabel

- (void)setText:(NSString *)text {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        if ([text hasPrefix:@"善语"] || [text hasPrefix:@"友爱评论"] || [text hasPrefix:@"回复"]) {
            self.textColor = [UIColor colorWithRed:125/255.0 green:125/255.0 blue:125/255.0 alpha:0.6];
        }
    }
    %orig;
}

%end

%hook UIButton
- (void)layoutSubviews {
    %orig;
    
    // 处理豆包按钮隐藏
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        // 1. 通过 accessibilityLabel 检测
        if ([self.accessibilityLabel isEqualToString:@"豆包"]) {
            [self removeFromSuperview];
            return;
        }
        
        // 2. 通过父视图类名检测
        UIView *parentView = self.superview;
        while (parentView) {
            NSString *className = NSStringFromClass([parentView class]);
            if ([className containsString:@"Doupack"] || [className containsString:@"豆包"]) {
                [self removeFromSuperview];
                return;
            }
            parentView = parentView.superview;
        }
        
        // 3. 通过图片名称检测
        UIImage *image = [self imageForState:UIControlStateNormal];
        if (image) {
            NSString *imageName = [image description];
            if ([imageName.lowercaseString containsString:@"doupack"] || 
                [imageName.lowercaseString containsString:@"豆包"]) {
                [self removeFromSuperview];
                return;
            }
        }
        
        // 4. 通过按钮标题检测
        NSString *title = [self titleForState:UIControlStateNormal];
        if ([title containsString:@"豆包"]) {
            [self removeFromSuperview];
            return;
        }
    }
    
    // 处理自动生成设置
    UIViewController *vc = [self firstAvailableUIViewController];
    if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)]) {
        DYYYButtonInfo *info = [DYYYButtonInfo infoWithClass:NSStringFromClass([self class])
                                                      label:self.accessibilityLabel
                                                      title:[self titleForState:UIControlStateNormal]
                                                      frame:self.frame];
        [[DYYYButtonManager sharedInstance] addButtonInfo:info];
    }
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    NSString *label = self.accessibilityLabel;
    if ([label isEqualToString:@"表情"] || [label isEqualToString:@"at"] || [label isEqualToString:@"图片"] || [label isEqualToString:@"键盘"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
            UIImage *whiteImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.tintColor = [UIColor whiteColor];
            %orig(whiteImage, state);
            return;
        }
    }
    %orig(image, state);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig;
    
    // 记录所有按钮点击
    NSString *buttonInfo = [NSString stringWithFormat:@"Button clicked - Class: %@, Label: %@, Title: %@",
                           NSStringFromClass([self class]),
                           self.accessibilityLabel ?: @"(no label)",
                           [self titleForState:UIControlStateNormal] ?: @"(no title)"];
    
    [[DYYYLogger sharedInstance] logEvent:buttonInfo];
    
    // 检查是否可能是豆包按钮
    BOOL isDoupackRelated = NO;
    
    // 1. 检查类名
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Doupack"] || [className containsString:@"豆包"]) {
        isDoupackRelated = YES;
    }
    
    // 2. 检查标识符
    if ([self.accessibilityLabel isEqualToString:@"豆包"]) {
        isDoupackRelated = YES;
    }
    
    // 3. 检查标题
    NSString *title = [self titleForState:UIControlStateNormal];
    if ([title containsString:@"豆包"]) {
        isDoupackRelated = YES;
    }
    
    if (isDoupackRelated) {
        // 收集豆包按钮相关的调试信息
        NSMutableString *debugInfo = [NSMutableString string];
        [debugInfo appendFormat:@"\n=== 豆包按钮点击事件 ===\n"];
        [debugInfo appendFormat:@"时间: %@\n", [NSDate date]];
        [debugInfo appendFormat:@"类名: %@\n", className];
        [debugInfo appendFormat:@"标识符: %@\n", self.accessibilityLabel];
        [debugInfo appendFormat:@"标题: %@\n", title];
        [debugInfo appendFormat:@"Frame: %@\n", NSStringFromCGRect(self.frame)];
        
        // 记录视图层级
        [debugInfo appendFormat:@"\n=== 视图层级 ===\n"];
        UIView *currentView = self;
        int depth = 0;
        while (currentView) {
            NSString *indent = [@"" stringByPaddingToLength:depth withString:@"  " startingAtIndex:0];
            [debugInfo appendFormat:@"%@%@\n", indent, NSStringFromClass([currentView class])];
            currentView = currentView.superview;
            depth++;
        }
        
        [[DYYYLogger sharedInstance] logEvent:debugInfo];
        [[DYYYDebugViewController sharedInstance] appendDebugInfo:debugInfo];
        [[DYYYDebugViewController sharedInstance] show];
    }
}

%end

%hook UIView

- (void)didMoveToSuperview {
    %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        // 检查是否是豆包相关视图
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"Doupack"] || 
            [self.accessibilityLabel isEqualToString:@"豆包"]) {
            self.hidden = YES;
            [self removeFromSuperview];
        }
    }
}

%end

%hook AWETextViewInternal

- (void)drawRect:(CGRect)rect {
    %orig(rect);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        self.textColor = [UIColor whiteColor];
    }
}

- (double)lineSpacing {
    double r = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        self.textColor = [UIColor whiteColor];
    }
    return r;
}

%end

%hook AWEPlayInteractionUserAvatarElement

- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYfollowTips"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController
                                                alertControllerWithTitle:@"关注确认"
                                                message:@"是否确认关注？"
                                                preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction
                                         actionWithTitle:@"取消"
                                         style:UIAlertActionStyleCancel
                                         handler:nil];
            
            UIAlertAction *confirmAction = [UIAlertAction
                                          actionWithTitle:@"确定"
                                          style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction * _Nonnull action) {
                %orig(gesture);
            }];
            
            [alertController addAction:cancelAction];
            [alertController addAction:confirmAction];
            
            UIWindow *mainWindow = GetMainWindow();
            UIViewController *topController = mainWindow.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            [topController presentViewController:alertController animated:YES completion:nil];
        });
    } else {
        %orig;
    }
}

%end

%hook AWEFeedVideoButton
- (id)touchUpInsideBlock {
    id r = %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYcollectTips"] && [self.accessibilityLabel isEqualToString:@"收藏"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController
                                                  alertControllerWithTitle:@"收藏确认"
                                                  message:@"是否[确认/取消]收藏？"
                                                  preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *cancelAction = [UIAlertAction
                                           actionWithTitle:@"取消"
                                           style:UIAlertActionStyleCancel
                                           handler:nil];

            UIAlertAction *confirmAction = [UIAlertAction
                                            actionWithTitle:@"确定"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                if (r && [r isKindOfClass:NSClassFromString(@"NSBlock")]) {
                    ((void(^)(void))r)();
                }
            }];

            [alertController addAction:cancelAction];
            [alertController addAction:confirmAction];

            UIWindow *mainWindow = GetMainWindow();
            UIViewController *topController = mainWindow.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            [topController presentViewController:alertController animated:YES completion:nil];
        });

        return nil;
    }

    return r;
}
%end

%hook AWEFeedProgressSlider

- (void)setAlpha:(CGFloat)alpha {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowSchedule"]) {
        alpha = 1.0;
        %orig(alpha);
    }else {
        %orig;
    }
}

%end

%hook AWENormalModeTabBarTextView

- (void)layoutSubviews {
    %orig;
    
    NSString *indexTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYIndexTitle"];
    NSString *friendsTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFriendsTitle"];
    NSString *msgTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYMsgTitle"];
    NSString *selfTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSelfTitle"];
    
    for (UIView *subview in [self subviews]) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:@"首页"]) {
                if (indexTitle.length > 0) {
                    [label setText:indexTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"朋友"]) {
                if (friendsTitle.length > 0) {
                    [label setText:friendsTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"消息"]) {
                if (msgTitle.length > 0) {
                    [label setText:msgTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"我"]) {
                if (selfTitle.length > 0) {
                    [label setText:selfTitle];
                    [self setNeedsLayout];
                }
            }
        }
    }
}
%end

%hook AWEFeedIPhoneAutoPlayManager

- (BOOL)isAutoPlayOpen {
    BOOL r = %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAutoPlay"]) {
        return YES;
    }
    return r;
}

%end

%hook AWEHPTopTabItemModel

- (void)setChannelID:(NSString *)channelID {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (([channelID isEqualToString:@"homepage_hot_container"] && [defaults boolForKey:@"DYYYHideHotContainer"]) ||
        ([channelID isEqualToString:@"homepage_follow"] && [defaults boolForKey:@"DYYYHideFollow"]) ||
        ([channelID isEqualToString:@"homepage_mediumvideo"] && [defaults boolForKey:@"DYYYHideMediumVideo"]) ||
        ([channelID isEqualToString:@"homepage_mall"] && [defaults boolForKey:@"DYYYHideMall"]) ||
        ([channelID isEqualToString:@"homepage_nearby"] && [defaults boolForKey:@"DYYYHideNearby"]) ||
        ([channelID isEqualToString:@"homepage_groupon"] && [defaults boolForKey:@"DYYYHideGroupon"]) ||
        ([channelID isEqualToString:@"homepage_tablive"] && [defaults boolForKey:@"DYYYHideTabLive"]) ||
        ([channelID isEqualToString:@"homepage_pad_hot"] && [defaults boolForKey:@"DYYYHidePadHot"]) ||
        ([channelID isEqualToString:@"homepage_hangout"] && [defaults boolForKey:@"DYYYHideHangout"])) {
        return;
    }
    %orig;
}

%end

%hook AWEPlayInteractionTimestampElement
-(id)timestampLabel{
	UILabel *label = %orig;
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"]){
		NSString *text = label.text;
		AWEAwemeModel *model = self.model;
		NSString *ipAttribution = model.ipAttribution;
		NSString *cityCode = model.cityCode;
		if (!ipAttribution && cityCode) {
			NSString *ipAttribution = [CityManager.sharedInstance getCityNameWithCode:cityCode];
			if (ipAttribution) {
				label.text = [NSString stringWithFormat:@"%@  IP属地：%@",text,ipAttribution];
			}
		}
	}
	return label;
}
+(BOOL)shouldActiveWithData:(id)arg1 context:(id)arg2{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
}

%end

%hook AWEPlayInteractionDoupackElement
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}
%end

%hook AWEDoupackContainerView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}

- (void)didMoveToSuperview {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}
%end

%hook AWEDoupackButton
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}

- (void)didMoveToSuperview {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}
%end

%hook AWEPlayInteractionDoupackView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}

- (void)didMoveToSuperview {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}
%end

%hook AWEDoupackIconView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}

- (void)didMoveToSuperview {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        self.hidden = YES;
        [self removeFromSuperview];
    }
}
%end

%hook UIView
- (void)didMoveToWindow {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDoupackButton"]) {
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"Doupack"] || 
            [className containsString:@"豆包"] || 
            [self.accessibilityLabel isEqualToString:@"豆包"]) {
            [self removeFromSuperview];
        }
    }
}
%end

// 添加网络请求拦截相关接口
@interface NSURLRequest (Private)
+ (void)setAllowsAnyHTTPSCertificate:(BOOL)allow forHost:(NSString *)host;
@end

@interface NSURLSession (Private)
+ (void)setAllowsAnyHTTPSCertificate:(BOOL)allow forHost:(NSString *)host;
@end

// 添加 URL Protocol 处理类
@interface DYYYURLProtocol : NSURLProtocol <NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *task;
@end

// 添加触摸事件监听
%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;
    
    if (event.type == UIEventTypeTouches) {
        for (UITouch *touch in event.allTouches) {
            if (touch.phase == UITouchPhaseBegan) {
                CGPoint location = [touch locationInView:touch.view];
                UIView *hitView = [touch.view hitTest:location withEvent:event];
                
                NSMutableString *touchInfo = [NSMutableString stringWithString:@"\n=== Touch Event ===\n"];
                [touchInfo appendFormat:@"Location: %@\n", NSStringFromCGPoint(location)];
                [touchInfo appendFormat:@"Hit View: %@ (Label: %@)\n", 
                    NSStringFromClass([hitView class]), 
                    hitView.accessibilityLabel ?: @""];
                
                [[DYYYLogger sharedInstance] logEvent:touchInfo];
                [[DYYYLogger sharedInstance] logViewHierarchy:hitView withTitle:@"Touch View Hierarchy"];
            }
        }
    }
}

%end

// 完整实现 DYYYURLProtocol 类
@implementation DYYYURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:@"DYYYURLProtocolHandled" inRequest:request]) {
        return NO;
    }
    
    NSString *urlString = request.URL.absoluteString;
    if ([urlString containsString:@"doubao.com"] || 
        [urlString containsString:@"tp-pay.snssdk.com"] ||
        [urlString containsString:@"gateway-u"] ||
        [urlString containsString:@"pay.snssdk.com"]) {
        
        // 记录相关网络请求
        NSMutableString *requestInfo = [NSMutableString stringWithString:@"\n=== 豆包相关请求拦截 ===\n"];
        [requestInfo appendFormat:@"URL: %@\n", urlString];
        [requestInfo appendFormat:@"Method: %@\n", request.HTTPMethod];
        [requestInfo appendFormat:@"Headers: %@\n", request.allHTTPHeaderFields];
        
        if (request.HTTPBody) {
            NSString *bodyString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
            [requestInfo appendFormat:@"Body: %@\n", bodyString];
        }
        
        [[DYYYLogger sharedInstance] logEvent:requestInfo];
        [[DYYYDebugViewController sharedInstance] appendDebugInfo:requestInfo];
        
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"DYYYURLProtocolHandled" inRequest:newRequest];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.task = [session dataTaskWithRequest:newRequest];
    [self.task resume];
}

- (void)stopLoading {
    [self.task cancel];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [[self client] URLProtocol:self didFailWithError:error];
    } else {
        [[self client] URLProtocolDidFinishLoading:self];
    }
}

@end

// 在 %ctor 中注册 URL Protocol 和允许的域名
%ctor {
    // 注册 URL Protocol
    [NSURLProtocol registerClass:[DYYYURLProtocol class]];
    
    // 允许自签名证书（用于调试）
    NSArray *domains = @[
        @"api-normal.doubao.com",
        @"tp-pay.snssdk.com",
        @"api.douyin.com",
        @"aweme.snssdk.com"
    ];
    
    for (NSString *domain in domains) {
        [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:domain];
    }
}

