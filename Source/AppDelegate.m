#import "AppDelegate.h"
#import "DatabaseManager.h"
#import "DashboardViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[DatabaseManager shared] setupDatabase];
    
    DashboardViewController *dashboardVC = [[DashboardViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dashboardVC];
    nav.navigationBar.hidden = YES;
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = nav;
    self.window.backgroundColor = [UIColor systemBackgroundColor];
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end