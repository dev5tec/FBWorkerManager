//
//  SampleQueue.h
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/04.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FBWorker.h"
#import "FBWorkerQueue.h"
#import "Sample.h"

@interface SampleQueue : NSObject <FBWorkerQueue>
@property (nonatomic, retain) NSMutableArray* list;
- (Sample*)objectAtIndex:(NSUInteger)index;
- (NSUInteger)indexOf:(Sample*)sample;
- (void)addSample:(Sample*)sample;
@end



