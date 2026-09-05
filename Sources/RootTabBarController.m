#import "RootTabBarController.h"
#import "OverviewViewController.h"
#import "ProcessesViewController.h"
#import "ActionsViewController.h"

@implementation RootTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    OverviewViewController *overview = [[OverviewViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    ProcessesViewController *processes = [[ProcessesViewController alloc] init];
    ActionsViewController *actions = [[ActionsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];

    UINavigationController *n1 = [[UINavigationController alloc] initWithRootViewController:overview];
    UINavigationController *n2 = [[UINavigationController alloc] initWithRootViewController:processes];
    UINavigationController *n3 = [[UINavigationController alloc] initWithRootViewController:actions];

    n1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Overview" image:[UIImage systemImageNamed:@"gauge"] tag:0];
    n2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Processes" image:[UIImage systemImageNamed:@"list.bullet.rectangle"] tag:1];
    n3.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Actions" image:[UIImage systemImageNamed:@"bolt.shield"] tag:2];

    self.viewControllers = @[n1, n2, n3];
}

@end
