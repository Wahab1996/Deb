#import "InspectorViewController.h"
#import "AppRecord.h"
#import "StateScanner.h"
#import "InspectionFinding.h"
#import "SnapshotStore.h"
#import "FindingDetailViewController.h"

@interface InspectorViewController ()
@property (nonatomic, strong) AppRecord *app;
@property (nonatomic, copy) NSArray<InspectionFinding *> *findings;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation InspectorViewController
- (instancetype)initWithApp:(AppRecord *)app {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) _app = app;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.app.name;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.findings = @[];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 3;
    return self.findings.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Target";
    if (section == 1) return @"Read-only analysis";
    return [NSString stringWithFormat:@"Findings (%lu)", (unsigned long)self.findings.count];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"Inspector does not write to the target app. Snapshot comparison is most useful with your own app or an authorized test build.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.detailTextLabel.numberOfLines = 2;
    if (indexPath.section == 0) {
        NSArray *labels = @[@"Bundle ID", @"Version", @"Bundle path", @"Data path"];
        NSArray *values = @[self.app.bundleID ?: @"—", self.app.version ?: @"—", self.app.bundleURL.path ?: @"Unavailable", self.app.dataURL.path ?: @"Unavailable"];
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = values[indexPath.row];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 1) {
        NSArray *labels = @[@"Scan likely state values", @"Snapshot Before", @"Compare After"];
        NSArray *details = @[@"Search plist, JSON and suspicious SQLite fields", @"Save current structured state", @"Show exact values that changed since the snapshot"];
        cell.textLabel.text = labels[indexPath.row];
        cell.detailTextLabel.text = details[indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        InspectionFinding *f = self.findings[indexPath.row];
        cell.textLabel.text = f.keyPath.length ? f.keyPath : f.category;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@", f.filePath.lastPathComponent, f.value];
        cell.detailTextLabel.numberOfLines = 3;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (indexPath.row == 0) [self runScan];
        else if (indexPath.row == 1) [self saveSnapshot];
        else [self compareSnapshot];
    } else if (indexPath.section == 2) {
        [self.navigationController pushViewController:[[FindingDetailViewController alloc] initWithFinding:self.findings[indexPath.row]] animated:YES];
    }
}

- (void)runBusy:(void (^)(void))work completion:(void (^)(void))completion {
    [self.spinner startAnimating];
    self.view.userInteractionEnabled = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        work();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.view.userInteractionEnabled = YES;
            if (completion) completion();
        });
    });
}

- (void)runScan {
    __block NSArray *results = nil;
    [self runBusy:^{ results = [StateScanner scanApp:self.app]; } completion:^{
        self.findings = results ?: @[];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationAutomatic];
        if (self.findings.count == 0) [self show:@"Scan complete" message:@"No purchase-state-like keys were found in the supported file types."];
    }];
}

- (void)saveSnapshot {
    __block NSDictionary *snapshot = nil;
    [self runBusy:^{ snapshot = [StateScanner snapshotApp:self.app]; } completion:^{
        NSError *error = nil;
        BOOL ok = [SnapshotStore saveSnapshot:snapshot bundleID:self.app.bundleID error:&error];
        [self show:ok ? @"Snapshot saved" : @"Snapshot failed" message:ok ? [NSString stringWithFormat:@"Captured %lu structured values.", (unsigned long)snapshot.count] : error.localizedDescription];
    }];
}

- (void)compareSnapshot {
    NSDictionary *before = [SnapshotStore loadSnapshotForBundleID:self.app.bundleID];
    if (!before) {
        [self show:@"No snapshot" message:@"Run Snapshot Before first, perform the authorized test action in the target app, then return and tap Compare After."];
        return;
    }
    __block NSDictionary *after = nil;
    [self runBusy:^{ after = [StateScanner snapshotApp:self.app]; } completion:^{
        self.findings = [StateScanner diffFrom:before to:after ?: @{}];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationAutomatic];
        if (self.findings.count == 0) [self show:@"No differences" message:@"No supported structured values changed since the snapshot."];
    }];
}

- (void)show:(NSString *)title message:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end
