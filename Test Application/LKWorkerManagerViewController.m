//
//  LKWorkerManagerViewController.m
//  LKWorkerManager
//
//
// icon
// http://www.iconfinder.com/icondetails/40717/128/blue_button_play_icon
// http://www.iconfinder.com/icondetails/40726/128/button_grey_pause_icon
// http://www.iconfinder.com/icondetails/40865/128/blue_delete_sub_icon
//

#import "LKWorkerManagerViewController.h"
#import "LKWorker.h"
#import "MyCell.h"


@implementation LKWorkerManagerViewController
@synthesize tableView = tableView_;
@synthesize queue;
@synthesize workerManager;
@synthesize cancelButton;


#pragma mark -
#pragma mark Private
- (void)_updateCellForWorker:(id <LKWorker>)worker
{
    NSUInteger row = [self.queue indexOf:worker];
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
    
    if (self.queue == nil) {
        self.queue = [[[SampleQueue alloc] init] autorelease];
        self.workerManager = [LKWorkerManager workerManagerWithWorkerQueue:self.queue];
        self.workerManager.delegate = self;
        [self.workerManager start];
    }
}

- (void)viewDidUnload
{
    self.tableView = nil;
    self.queue = nil;
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
    return [self.queue count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"MyCell";

    MyCell *cell = (MyCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        UINib* nib = [UINib nibWithNibName:cellIdentifier bundle:nil];
        cell = [[nib instantiateWithOwner:self options:nil] objectAtIndex:0];
    }
    Sample* obj = [self.queue objectAtIndex:indexPath.row];
    cell.title.text = obj.title;
    cell.progressView.progress = obj.progress;
    
    switch (obj.workerState) {
        case LKWorkerStateWaiting:
            [cell.indicator stopAnimating];        
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = YES;        
            cell.cancelButton.hidden = NO;
            cell.label.text = @"Waiting";
            break;
            
        case LKWorkerStateExecuting:
            [cell.indicator startAnimating];
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = NO;        
            cell.cancelButton.hidden = NO;
            [cell.stopStartButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
            cell.label.text = @"Executing";
            break;

        case LKWorkerStateSuspending:
            [cell.indicator stopAnimating];
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = NO;
            cell.cancelButton.hidden = NO;
            [cell.stopStartButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
            cell.label.text = @"Suspended";
            break;

        case LKWorkerStateCompleted:
            [cell.indicator stopAnimating];        
            cell.progressView.hidden = NO;
            cell.stopStartButton.hidden = YES;
            cell.cancelButton.hidden = YES;
            cell.label.text = @"Completed";
            break;

        case LKWorkerStateCanceled:
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
    self.queue = nil;
    self.workerManager = nil;
    self.cancelButton = nil;
    [super dealloc];
}

- (IBAction)add:(id)sender {
    static int i=1;
    Sample* obj = [[[Sample alloc] init] autorelease];
    obj.title = [NSString stringWithFormat:@"WORKER - %02d", i++];
    obj.time = [NSDate date];
    [self.queue addSample:obj];
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.queue count]-1
                                                inSection:0];
    NSArray* paths = [NSArray arrayWithObject:indexPath];
    [self.tableView insertRowsAtIndexPaths:paths
                          withRowAnimation:UITableViewRowAnimationTop];
    [self.tableView scrollToRowAtIndexPath:indexPath
                          atScrollPosition:UITableViewScrollPositionNone
                                  animated:YES];
    [UIApplication sharedApplication].applicationIconBadgeNumber = [self.queue count];
}

- (IBAction)cancelAllWorkers:(id)sender
{    
    [self.workerManager cancelAll];
    [self.tableView reloadData];
}

- (IBAction)pauseAllWorkers:(id)sender
{
    [self.workerManager suspendAll];
    [self.tableView reloadData];
}

- (IBAction)resumeAllWorkers:(id)sender
{
    [self.workerManager resumeAll];
    [self.tableView reloadData];
}

- (IBAction)suspendResumeWorker:(id)sender event:(UIEvent*)event
{
    UITouch* touch = [[event allTouches] anyObject];
    CGPoint p = [touch locationInView:self.tableView];
    NSIndexPath* indexPath = [self.tableView indexPathForRowAtPoint:p];
    Sample* sample = [self.queue objectAtIndex:indexPath.row];
    if (sample.workerState == LKWorkerStateExecuting) {
        [self.workerManager suspendWorker:sample];
    } else if (sample.workerState == LKWorkerStateSuspending) {
        [self.workerManager resumeWorker:sample];
    }
    [self _updateCellForWorker:sample];
}

- (IBAction)cancelWorker:(id)sender event:(UIEvent*)event
{
    UITouch* touch = [[event allTouches] anyObject];
    CGPoint p = [touch locationInView:self.tableView];
    NSIndexPath* indexPath = [self.tableView indexPathForRowAtPoint:p];
    Sample* sample = [self.queue objectAtIndex:indexPath.row];
    [self.workerManager cancelWorker:sample];
}


#pragma mark -
#pragma mark LKWokerManagerDelegate
/*
- (BOOL)canWorkerManagerRun
{
    return [self.queue count];
}
 */

- (void)willBeginWorkerManager:(LKWorkerManager *)workerManager worker:(id<LKWorker>)worker
{
    [self _updateCellForWorker:worker];
}

- (void)didUpdateWorkerManager:(LKWorkerManager *)workerManager worker:(id<LKWorker>)worker
{
    Sample* sample = (Sample*)worker;
    NSUInteger row = [self.queue indexOf:sample];
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    MyCell* cell = (MyCell*)[self.tableView cellForRowAtIndexPath:indexPath];
    cell.progressView.progress = sample.progress;
}

static NSInteger finishedCounter_ = 0;
- (void)didFinishWorkerManager:(LKWorkerManager *)workerManager worker:(id<LKWorker>)worker
{
    [self _updateCellForWorker:worker];
    finishedCounter_++;
    [UIApplication sharedApplication].applicationIconBadgeNumber = [self.queue count] - finishedCounter_;
}

@end
