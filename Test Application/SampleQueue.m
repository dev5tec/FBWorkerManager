//
//  SampleQueue.m
//  FBWorkerManager
//
//  Created by Hashiguchi Hiroshi on 11/08/04.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#import "SampleQueue.h"

@implementation SampleQueue
@synthesize list;

- (id)init {
    self = [super init];
    if (self) {
        self.list = [NSMutableArray array];
    }
    return self;
}

- (Sample*)objectAtIndex:(NSUInteger)index
{
    return [self.list objectAtIndex:index];
}

- (NSUInteger)indexOf:(Sample*)obj
{
    NSUInteger row = 0;
    for (Sample* sample in self.list) {
        if (sample == obj) {
            break;
        }
        row++;
    }
    if (row == [self.list count]) {
        return -1;
    }
    return row;
}

- (void)addSample:(Sample*)sample
{
    [self.list addObject:sample];
}

- (id <FBWorker>)nextWorker
{
    NSArray* copiedList = [[self.list copy] autorelease];
    for (Sample* sample in copiedList) {
        if (sample.workerState == FBWorkerStateWaiting) {
            sample.workerState = FBWorkerStateExecuting;
            return sample;
        }
        
    }
    return nil;
}

- (NSUInteger)count
{
    return [self.list count];
}


@end
