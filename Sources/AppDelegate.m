#import "AppDelegate.h"
#import "AppsViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    AppsViewController *apps = [[AppsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:apps];
    nav.navigationBar.prefersLargeTitles = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
