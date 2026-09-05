#import "ActionsViewController.h"
#import "CommandRunner.h"

@implementation ActionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Actions";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return section == 0 ? 2 : 1; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"SYSTEM ACTIONS" : @"CACHE";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) return @"These actions require confirmation. Availability depends on the jailbreak bootstrap and command privileges.";
    return @"uicache refreshes application registration and icons.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"action"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"action"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"Respring";
        cell.detailTextLabel.text = @"Reload SpringBoard";
        cell.imageView.image = [UIImage systemImageNamed:@"arrow.clockwise.circle"];
    } else if (indexPath.section == 0) {
        cell.textLabel.text = @"Userspace Reboot";
        cell.detailTextLabel.text = @"Restart userspace without a full hardware reboot";
        cell.imageView.image = [UIImage systemImageNamed:@"power.circle"];
    } else {
        cell.textLabel.text = @"Refresh Icon Cache";
        cell.detailTextLabel.text = @"Run uicache --all";
        cell.imageView.image = [UIImage systemImageNamed:@"square.grid.2x2"];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *title = nil;
    NSString *message = nil;
    if (indexPath.section == 0 && indexPath.row == 0) {
        title = @"Confirm Respring";
        message = @"SpringBoard will restart immediately.";
    } else if (indexPath.section == 0) {
        title = @"Confirm Userspace Reboot";
        message = @"All apps and jailbreak userspace services will restart. Save your work first.";
    } else {
        title = @"Refresh Icon Cache";
        message = @"This will rebuild app registration/icon cache.";
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Run" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self runActionAtIndexPath:indexPath];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)runActionAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *candidates = nil;
    NSArray *arguments = @[];
    if (indexPath.section == 0 && indexPath.row == 0) {
        candidates = @[@"/var/jb/usr/bin/sbreload", @"/var/jb/usr/bin/ldrestart"];
    } else if (indexPath.section == 0) {
        candidates = @[@"/var/jb/bin/launchctl", @"/bin/launchctl"];
        arguments = @[@"reboot", @"userspace"];
    } else {
        candidates = @[@"/var/jb/usr/bin/uicache", @"/usr/bin/uicache"];
        arguments = @[@"--all"];
    }

    [CommandRunner runExecutableCandidates:candidates arguments:arguments completion:^(int exitCode, NSString *message) {
        // Successful respring/userspace reboot may terminate this app before this alert appears.
        UIAlertController *result = [UIAlertController alertControllerWithTitle:(exitCode == 0 ? @"Completed" : @"Action Failed") message:message preferredStyle:UIAlertControllerStyleAlert];
        [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:result animated:YES completion:nil];
    }];
}

@end
