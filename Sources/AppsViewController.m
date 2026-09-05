#import "AppsViewController.h"
#import "AppDiscovery.h"
#import "AppRecord.h"
#import "InspectorViewController.h"

@interface AppsViewController ()
@property (nonatomic, copy) NSArray<AppRecord *> *apps;
@property (nonatomic, copy) NSArray<AppRecord *> *filtered;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation AppsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Installed Apps";
    self.tableView.rowHeight = 64.0;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadApps)];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"App name or Bundle ID";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    [self reloadApps];
}

- (void)reloadApps {
    self.apps = [AppDiscovery installedUserApps];
    self.filtered = self.apps;
    [self.tableView reloadData];

    if (self.apps.count == 0) {
        UILabel *label = [[UILabel alloc] initWithFrame:self.tableView.bounds];
        label.text = @"No apps found. This build needs jailbreak-level container access.";
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.textColor = UIColor.secondaryLabelColor;
        self.tableView.backgroundView = label;
    } else {
        self.tableView.backgroundView = nil;
    }
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *q = searchController.searchBar.text.lowercaseString;
    if (q.length == 0) {
        self.filtered = self.apps;
    } else {
        NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(AppRecord *app, NSDictionary *bindings) {
            return [app.name.lowercaseString containsString:q] || [app.bundleID.lowercaseString containsString:q];
        }];
        self.filtered = [self.apps filteredArrayUsingPredicate:p];
    }
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"app";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    AppRecord *app = self.filtered[indexPath.row];
    cell.textLabel.text = app.name;
    cell.detailTextLabel.text = app.bundleID;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    InspectorViewController *vc = [[InspectorViewController alloc] initWithApp:self.filtered[indexPath.row]];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
