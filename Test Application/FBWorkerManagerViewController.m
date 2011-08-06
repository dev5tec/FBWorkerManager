//
//  FBWorkerManagerViewController.m
//  FBWorkerManager
//
//
// icon
// http://www.iconfinder.com/icondetails/40717/128/blue_button_play_icon
// http://www.iconfinder.com/icondetails/40726/128/button_grey_pause_icon
// http://www.iconfinder.com/icondetails/40865/128/blue_delete_sub_icon
//

#import "FBWorkerManagerViewController.h"
#import "FBWorker.h"
#import "MyCell.h"


@implementation FBWorkerManagerViewController
@synthesize tableView = tableView_;
@synthesize list;
@synthesize workerManager;
@synthesize cancelButton;


#pragma mark -
#pragma mark Private
- (void)_updateCellForWorker:(id <FBWorker>)worker
{
    NSUInteger row = [self.list indexOfObject:worker];
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                          withRowAnimation:UITableViewRowAnimationNone];
}


#pragma mark -
#pragma mark Basics

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.list == nil) {
        self.list = [NSMutableArray array];
        self.workerManager = [FBWorkerManager workerManager];
        self.workerManager.delegate = self;
        self.workerManager.workerSource = self;
        self.workerManager.maxWorkers = 3;
        [self.workerManager start];
    }
}

- (void)viewDidUnload
{
    self.tableView = nil;
    self.list = nil;
    self.workerManager = nil;
    self.cancelButton = nil;
    [super viewDidUnload];    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.list count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"MyCell";

    MyCell *cell = (MyCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        UINib* nib = [UINib nibWithNibName:cellIdentifier bundle:nil];
        cell = [[nib instantiateWithOwner:self options:nil] objectAtIndex:0];
    }
    SampleWorker* obj = [self.list objectAtIndex:indexPath.row];
    cell.title.text = obj.title;
    cell.progressView.progress = obj.progress;
    
    switch (obj.workerState) {
        case FBWorkerStateWaiting:
            [cell.indicator stopAnimating];        
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = YES;        
            cell.cancelButton.hidden = NO;
            cell.label.text = @"Waiting";
            break;
            
        case FBWorkerStateExecuting:
            [cell.indicator startAnimating];
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = NO;        
            cell.cancelButton.hidden = NO;
            [cell.stopStartButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
            cell.label.text = @"Executing";
            break;

        case FBWorkerStateSuspending:
            [cell.indicator stopAnimating];
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = NO;
            cell.cancelButton.hidden = NO;
            [cell.stopStartButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
            cell.label.text = @"Suspended";
            break;

        case FBWorkerStateCompleted:
            [cell.indicator stopAnimating];        
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = YES;
            cell.cancelButton.hidden = YES;
            cell.label.text = @"Completed";
            break;

        case FBWorkerStateCanceled:
            [cell.indicator stopAnimating];        
            cell.progressView.hidden = YES;
            cell.stopStartButton.hidden = YES;
            cell.cancelButton.hidden = YES;
            cell.label.text = @"Canceled";
            break;

    }
    return cell;
}

- (void)dealloc {
    self.tableView = nil;
    self.list = nil;
    self.workerManager = nil;
    self.cancelButton = nil;
    [super dealloc];
}

- (IBAction)add:(id)sender {
    static int i=1;
    SampleWorker* obj = [[[SampleWorker alloc] init] autorelease];
    obj.title = [NSString stringWithFormat:@"WORKER - %02d", i++];
    obj.time = [NSDate date];
    [self.list addObject:obj];
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.list count]-1
                                                inSection:0];
    NSArray* paths = [NSArray arrayWithObject:indexPath];
    [self.tableView insertRowsAtIndexPaths:paths
                          withRowAnimation:UITableViewRowAnimationTop];
    [self.tableView scrollToRowAtIndexPath:indexPath
                          atScrollPosition:UITableViewScrollPositionNone
                                  animated:YES];
    [UIApplication sharedApplication].applicationIconBadgeNumber = [self.list count];
}

- (IBAction)cancelAllWorkers:(id)sender
{
    for (id <FBWorker> worker in self.list) {
        [self.workerManager cancelWorker:worker];
    }
    [self.tableView reloadData];
}

- (IBAction)pauseAllWorkers:(id)sender
{
    [self.workerManager stop];
    for (id <FBWorker> worker in self.list) {
        [self.workerManager suspendWorker:worker];
    }
    [self.tableView reloadData];
}

- (IBAction)resumeAllWorkers:(id)sender
{
    for (id <FBWorker> worker in self.list) {
        [self.workerManager resumeWorker:worker];
    }
    [self.tableView reloadData];
    [self.workerManager start];
}

- (IBAction)suspendResumeWorker:(id)sender event:(UIEvent*)event
{
    UITouch* touch = [[event allTouches] anyObject];
    CGPoint p = [touch locationInView:self.tableView];
    NSIndexPath* indexPath = [self.tableView indexPathForRowAtPoint:p];
    SampleWorker* sample = [self.list objectAtIndex:indexPath.row];
    if (sample.workerState == FBWorkerStateExecuting) {
        [self.workerManager suspendWorker:sample];
    } else if (sample.workerState == FBWorkerStateSuspending) {
        [self.workerManager resumeWorker:sample];
    }
    [self _updateCellForWorker:sample];
}

- (IBAction)cancelWorker:(id)sender event:(UIEvent*)event
{
    UITouch* touch = [[event allTouches] anyObject];
    CGPoint p = [touch locationInView:self.tableView];
    NSIndexPath* indexPath = [self.tableView indexPathForRowAtPoint:p];
    SampleWorker* sample = [self.list objectAtIndex:indexPath.row];
    [self.workerManager cancelWorker:sample];
}


#pragma mark -
#pragma mark FBWokerManagerDelegate
/*
- (BOOL)canWorkerManagerRun
{
    return [self.list count];
}
 */

- (void)willBeginWorkerManager:(FBWorkerManager *)workerManager worker:(id<FBWorker>)worker
{
    [self _updateCellForWorker:worker];
}

- (void)didUpdateWorkerManager:(FBWorkerManager *)workerManager worker:(id<FBWorker>)worker
{
    SampleWorker* sample = (SampleWorker*)worker;
    NSUInteger row = [self.list indexOfObject:sample];
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    MyCell* cell = (MyCell*)[self.tableView cellForRowAtIndexPath:indexPath];
    cell.progressView.progress = sample.progress;
}

static NSInteger finishedCounter_ = 0;
- (void)didFinishWorkerManager:(FBWorkerManager *)workerManager worker:(id<FBWorker>)worker
{
    [self _updateCellForWorker:worker];
    finishedCounter_++;
    [UIApplication sharedApplication].applicationIconBadgeNumber = [self.list count] - finishedCounter_;
}


#pragma mark -
#pragma mark FBWorkerManagerSource
- (id <FBWorker>)nextWorkerWithWorkerManager:(FBWorkerManager*)workerManager
{
    NSArray* copiedList = [[self.list copy] autorelease];
    for (SampleWorker* sample in copiedList) {
        if (sample.workerState == FBWorkerStateWaiting) {
            return sample;
        }
        
    }
    return nil;
}

@end
