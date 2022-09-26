//
//  ViewController.m
//  ios-bluetooth-peripheral
//
//  Created by Simon Taylor on 23/09/2022.
//

#import "ViewController.h"

@interface ViewController ()


@end

@implementation ViewController
{
    CBPeripheralManager* peripheralManager_;
    
    CBUUID* serviceUUID_;
    CBMutableService* service_;
    
    CBUUID* countCharacteristicUUID_;
    CBMutableCharacteristic* countCharacteristic_;
    uint16_t currentCount_;
    
    CBUUID* channelCharacteristicUUID_;
    CBMutableCharacteristic* channelCharacteristic_;
    CBL2CAPPSM channelPSM_;
    CBL2CAPChannel* openChannel_;
    
    BOOL countCharacteristicActive_;
    BOOL channelActive_;
    
    NSTimer* timer_;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self startPeripheral];
}

- (void)startPeripheral {
    serviceUUID_ = [CBUUID UUIDWithString:@"13640001-4EC4-4D67-AEAC-380C85DF4043"];
    countCharacteristicUUID_ = [CBUUID UUIDWithString:@"13640002-4EC4-4D67-AEAC-380C85DF4043"];
    channelCharacteristicUUID_ = [CBUUID UUIDWithString:@"13640003-4EC4-4D67-AEAC-380C85DF4043"];
    
    
    service_ = [[CBMutableService alloc] initWithType:serviceUUID_ primary:YES];
    
    currentCount_ = 0;
    countCharacteristic_ = [[CBMutableCharacteristic alloc]
                                initWithType:countCharacteristicUUID_
                                properties:CBCharacteristicPropertyNotify
                                value:nil
                                permissions:CBAttributePermissionsReadable];
    
    channelCharacteristic_ = [[CBMutableCharacteristic alloc]
                              initWithType:channelCharacteristicUUID_
                              properties:CBCharacteristicPropertyRead
                              value:nil
                              permissions:CBAttributePermissionsReadable];
    
    service_.characteristics = @[countCharacteristic_, channelCharacteristic_];
    
    timer_ = [NSTimer scheduledTimerWithTimeInterval:0.03 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if(!(self->countCharacteristicActive_ || self->channelActive_)) return;
        
        self->currentCount_++;
        if(self->countCharacteristicActive_) {
            [self->peripheralManager_ updateValue:[NSData dataWithBytes:&self->currentCount_ length:2] forCharacteristic:self->countCharacteristic_ onSubscribedCentrals:nil];
        }
        
        if(self->channelActive_) {
            [self->openChannel_.outputStream write:(uint8_t*)&self->currentCount_ maxLength:2];
        }
    }];
    
    peripheralManager_ = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if(peripheral.state >= CBManagerStatePoweredOn) {
        NSLog(@"Powered on state");
        
        [peripheralManager_ addService:service_];
        [peripheralManager_ publishL2CAPChannelWithEncryption:NO];
    }
}


- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(nullable NSError *)error
{
    NSLog(@"didStartAdvertising");
    if(error != nil) {
        NSLog(@"error starting advertising: %@", error);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(nullable NSError *)error
{
    NSLog(@"didAddService");
    if(error != nil) {
        NSLog(@"error adding service: %@", error);
    }
    
    [peripheral startAdvertising:@{
        CBAdvertisementDataServiceUUIDsKey : @[service.UUID],
        CBAdvertisementDataLocalNameKey: @"iOS Demo"
    }];
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"central:didSubscribeToCharacteristic");
    if(characteristic == countCharacteristic_) countCharacteristicActive_ = YES;
    
    // Lower latency
    [peripheralManager_ setDesiredConnectionLatency:CBPeripheralManagerConnectionLatencyLow forCentral:central];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"central:didUnsubscribeFromCharacteristic");
    if(characteristic == countCharacteristic_) countCharacteristicActive_ = NO;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    NSLog(@"didReceiveReadRequest");
    if(![request.characteristic.UUID isEqual:channelCharacteristicUUID_]) {
        [peripheral respondToRequest:request
                          withResult:CBATTErrorAttributeNotFound];
        return;
    };
    
    if (request.offset >= 2) {
        [peripheral respondToRequest:request
                          withResult:CBATTErrorInvalidOffset];
        return;
    }
    
    uint8_t* psmBytes = (uint8_t*)&channelPSM_;
    request.value = [NSData dataWithBytes:&psmBytes[request.offset] length:(2-request.offset)];
    [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    NSLog(@"didReceiveWriteRequests");
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerIsReadyToUpdateSubscribers");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didPublishL2CAPChannel:(CBL2CAPPSM)PSM error:(nullable NSError *)error
{
    NSLog(@"didPublishL2CAPChannel: %hu", PSM);
    if(error != nil) {
        NSLog(@"error publishing channel: %@", error);
        return;
    }
    channelPSM_ = PSM;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didUnpublishL2CAPChannel:(CBL2CAPPSM)PSM error:(nullable NSError *)error
{
    NSLog(@"didUnpublishL2CAPChannel");
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didOpenL2CAPChannel:(nullable CBL2CAPChannel *)channel error:(nullable NSError *)error
{
    NSLog(@"didOpenL2CAPChannel");
    if(error != 0) {
        NSLog(@"Error opening channel: %@", error);
        return;
    }
    
    openChannel_ = channel;
    [openChannel_.outputStream open];
    channelActive_ = YES;
}

@end
