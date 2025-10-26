#import "PlayerSettingsController.h"

@implementation PlayerSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = LOC(@"PLAYER_SETTINGS");
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 7;
    if (section == 1) return 2; // Audio/Video and Crossfade
    if (section == 2) return 3;
    if (section == 3) return 2;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *YTMUltimateDict = [defaults dictionaryForKey:@"YTMUltimate"];
    if (!YTMUltimateDict) YTMUltimateDict = @{};

    UITableViewCell *cell;

    // --- Section 1: Audio/Video default mode ---
    if (indexPath.section == 1 && indexPath.row == 0) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"avCell"];
        cell.textLabel.text = LOC(@"AV_DEFAULT_MODE");

        UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:@[LOC(@"AUDIO"), LOC(@"VIDEO")]];
        control.selectedSegmentIndex = [YTMUltimateDict[@"audioVideoMode"] integerValue];
        [control addTarget:self action:@selector(controlSelect:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
        return cell;
    }

    // --- Section 1: Crossfade slider ---
    if (indexPath.section == 1 && indexPath.row == 1) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"crossfadeCell"];
        cell.textLabel.text = LOC(@"CROSSFADE");
        cell.detailTextLabel.text = LOC(@"CROSSFADE_DESC");
        cell.detailTextLabel.numberOfLines = 0;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        // Container for slider + label
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
        container.userInteractionEnabled = YES;

        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectZero];
        slider.minimumValue = 1.0;
        slider.maximumValue = 10.0;
        NSInteger currentVal = [YTMUltimateDict[@"crossfadeSeconds"] integerValue];
        if (currentVal <= 0) currentVal = 5;
        slider.value = currentVal;
        slider.tag = 12345;
        [slider addTarget:self action:@selector(crossfadeSliderChanged:) forControlEvents:UIControlEventValueChanged];

        UILabel *valLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        valLabel.text = [NSString stringWithFormat:@"%lds", (long)lround(slider.value)];
        valLabel.textAlignment = NSTextAlignmentRight;
        valLabel.tag = 12346;
        valLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];

        [container addSubview:slider];
        [container addSubview:valLabel];
        slider.translatesAutoresizingMaskIntoConstraints = NO;
        valLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [NSLayoutConstraint activateConstraints:@[
            [slider.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [slider.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [valLabel.leadingAnchor constraintEqualToAnchor:slider.trailingAnchor constant:8],
            [valLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [valLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
            [valLabel.widthAnchor constraintEqualToConstant:40]
        ]];

        cell.accessoryView = container;
        return cell;
    }

    // --- Fallback ---
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"defaultCell"];
    cell.textLabel.text = @"";
    return cell;
}

#pragma mark - Crossfade slider logic

- (void)crossfadeSliderChanged:(UISlider *)slider {
    NSInteger rounded = lround(slider.value);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"YTMUltimate"]];
    if (!dict) dict = [NSMutableDictionary new];
    dict[@"crossfadeSeconds"] = @(rounded);
    [defaults setObject:dict forKey:@"YTMUltimate"];
    [defaults synchronize];

    UIView *container = slider.superview;
    for (UIView *v in container.subviews) {
        if ([v isKindOfClass:[UILabel class]] && v.tag == 12346) {
            ((UILabel *)v).text = [NSString stringWithFormat:@"%lds", (long)rounded];
        }
    }
}

#pragma mark - Switch / Segmented handlers

- (void)toggleSwitch:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"YTMUltimate"]];
    dict[@"someKey"] = @(sender.isOn);
    [defaults setObject:dict forKey:@"YTMUltimate"];
    [defaults synchronize];
}

- (void)controlSelect:(UISegmentedControl *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:@"YTMUltimate"]];
    dict[@"audioVideoMode"] = @(sender.selectedSegmentIndex);
    [defaults setObject:dict forKey:@"YTMUltimate"];
    [defaults synchronize];
}

#pragma mark - Keyboard toolbar

- (UIView *)KBToolbar:(UITextField *)textField {
    UIToolbar *toolbar = [[UIToolbar alloc] init];
    toolbar.barStyle = UIBarStyleDefault;

    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(hideKeyboard)];

    [toolbar setItems:@[flexible, done]];
    [toolbar sizeToFit];
    return toolbar;
}

- (void)hideKeyboard {
    [self.view endEditing:YES];
}

@end
