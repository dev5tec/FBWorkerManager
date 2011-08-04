//
//  LKWorkerManagerViewController.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/01.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LKWorker.h"
#import "LKWorkerQueue.h"
#import "LKWorkerManager.h"
#import "Sample.h"

//-----------------------------------------------------
@interface SampleQueue : NSObject <LKWorkerQueue>
@property (nonatomic, retain) NSMutableArray* list;
- (Sample*)objectAtIndex:(NSUInteger)index;
- (NSUInteger)indexOf:(Sample*)sample;
- (void)addSample:(Sample*)sample;
@end


//-----------------------------------------------------
@interface LKWorkerManagerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, LKWorkerManagerDelegate> {
    UIBarButtonItem *control;
}


@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) SampleQueue* queue;
@property (nonatomic, retain) LKWorkerManager* workerManager;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *cancelButton;

- (IBAction)add:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)resume:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)stopStart:(id)sender event:(UIEvent*)event;
- (IBAction)cancelWorker:(id)sender event:(UIEvent*)event;
@end
