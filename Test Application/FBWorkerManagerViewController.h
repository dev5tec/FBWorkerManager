//
//  FBWorkerManagerViewController.h
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FBWorkerManager.h"
#import "Sample.h"
#import "SampleQueue.h"

@interface FBWorkerManagerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, FBWorkerManagerDelegate> {
    UIBarButtonItem *control;
}


@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) SampleQueue* queue;
@property (nonatomic, retain) FBWorkerManager* workerManager;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *cancelButton;

- (IBAction)add:(id)sender;
- (IBAction)pauseAllWorkers:(id)sender;
- (IBAction)resumeAllWorkers:(id)sender;
- (IBAction)cancelAllWorkers:(id)sender;

- (IBAction)suspendResumeWorker:(id)sender event:(UIEvent*)event;
- (IBAction)cancelWorker:(id)sender event:(UIEvent*)event;
@end
