//
//  Sample.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/03.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKWorker.h"

#define STATUS_LABEL_WAITING     @"Waiting"
#define STATUS_LABEL_WORKING    @"Working..."
#define STATUS_LABEL_FINISHED   @"Finished"
#define STATUS_LABEL_CANCELED   @"Canceled"
#define STATUS_LABEL_PAUSED     @"Paused"


@interface Sample : NSObject <LKWorker> 
@property (nonatomic, copy) NSString* title;
@property (copy) NSString* status;
@property (nonatomic, retain) NSDate* time;
@property (nonatomic, assign) CGFloat progress;
@end
