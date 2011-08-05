//
//  SampleQueue.h
//  LKWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/04.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKWorker.h"
#import "LKWorkerQueue.h"
#import "Sample.h"

@interface SampleQueue : NSObject <LKWorkerQueue>
@property (nonatomic, retain) NSMutableArray* list;
- (Sample*)objectAtIndex:(NSUInteger)index;
- (NSUInteger)indexOf:(Sample*)sample;
- (void)addSample:(Sample*)sample;
@end



