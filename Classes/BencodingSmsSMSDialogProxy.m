/**
 * benCoding.SMS Project
 * Copyright (c) 2012-2014 by Ben Bahrenburg. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "BencodingSmsSMSDialogProxy.h"
#import "TiUtils.h"
#import "TiApp.h"
#import "TiBlob.h"

BOOL lockPortrait = NO;
BOOL statusBarHiddenCheck = NO;
BOOL statusBarHiddenOldValue = NO;

@implementation MFMessageComposeViewController (AutoRotation)


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if(lockPortrait==YES)
    {
        return NO;
    }
    else
    {
        //Check if the orientation is supported in the Tiapp.xml settings
        BOOL allowRotate = [[[TiApp app] controller] shouldAutorotateToInterfaceOrientation:interfaceOrientation];
        //If it is supported, we need to move the entire app. 
        //Without doing this, our keyboard wont reposition itself
        if(allowRotate==YES)
        {
            [[UIApplication sharedApplication] setStatusBarOrientation:interfaceOrientation animated:NO];
        }
        //We tell the app if we can rotate, ie is this a support orientation
        return allowRotate;        
    }
}

@end

@implementation BencodingSmsSMSDialogProxy

@synthesize canSendText = _canSendText;
@synthesize canSendAttachment = _canSendAttachment;

-(id)init
{
    if (self = [super init])
    {
        showAnimated=YES;
        BOOL deviceCanSend = YES;
        BOOL canSendAttachment = YES;
        Class messageClass = (NSClassFromString(@"MFMessageComposeViewController"));
        if (messageClass == nil)
        {
            deviceCanSend = NO;
            canSendAttachment = NO;
        }
        else
        {
            //Check if we have support
            if([MFMessageComposeViewController canSendText]==NO)
            {
                deviceCanSend=NO;
            }
            
            if([MFMessageComposeViewController canSendAttachments]==NO)
            {
                canSendAttachment=NO;
            }
        }
        //Set a property so that we know if we can send a text message
        _canSendText=NUMBOOL(deviceCanSend);
        _canSendAttachment=NUMBOOL(canSendAttachment);
    
    }
    
    return self;  
}

-(void) resetFlags
{
    lockPortrait = NO;
    statusBarHiddenCheck = NO;
    statusBarHiddenOldValue = NO;
}


-(void)_destroy
{
    [super _destroy];
}

- (void) dealloc
{
	[super dealloc];
}


-(void)open:(id)args
{
    showAnimated=YES; //Force reset in case dev wants to toggle
    BOOL deviceCanSend = YES;
    BOOL canSendAttachment = YES;
    
    //Reset our flags in case we are calling many times with different values
    [self resetFlags];
    
    //Check the message class exists
    Class messageClass = (NSClassFromString(@"MFMessageComposeViewController"));
    if (messageClass == nil)
    {
        deviceCanSend=NO;
    }else
    {
        messageClass=nil;
        
        //Check if we have support
        if([MFMessageComposeViewController canSendText]==NO)
        {
            deviceCanSend=NO;
        }
        
        if([MFMessageComposeViewController canSendAttachments]==NO)
        {
            canSendAttachment=NO;
        }
    }

    if(deviceCanSend==NO)
    {
        if ([self _hasListeners:@"errored"]) {
            NSDictionary *errorEvent = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"Your device does not support sending text messages",@"message",
                                        nil
                                        ];
            
            [self fireEvent:@"errored" withObject:errorEvent];
        }         
        return;
    }
    
	//We need to do a few checks here to figure out what to do
    //This check is due to some side effects
    if((args ==nil)||([args count] == 0))
    {
        //If no arguments are passed we need to take a different action
        ENSURE_TYPE_OR_NIL(args,NSDictionary);
    }
    else        
    {
        //If there are agruments we need to do this
        //Get the user's animated option if provided
        ENSURE_SINGLE_ARG(args,NSDictionary);
        showAnimated = [TiUtils boolValue:@"animated" properties:args def:YES];
        lockPortrait= [TiUtils boolValue:@"portraitOnly" properties:args def:NO];
    }
    
	Class arrayClass = [NSArray class];
	NSArray * toArray = [self valueForUndefinedKey:@"toRecipients"];
    ENSURE_CLASS_OR_NIL(toArray,arrayClass);
    
    //Make sure we're on the UI thread, this stops bad things
	ENSURE_UI_THREAD(open,args);
    
    //Grab the message
    NSString * message = [TiUtils stringValue:[self valueForUndefinedKey:@"messageBody"]];
    
    MFMessageComposeViewController * smsComposer = [[MFMessageComposeViewController alloc] init];
    [smsComposer setMessageComposeDelegate:self];
    //Build the message contents
    smsComposer.body = message;
    smsComposer.recipients = toArray;
    
    //Check if we need to hide the statusbar
    BOOL statusBarHidden = [TiUtils boolValue:[self valueForUndefinedKey:@"statusBarHidden"] def:NO];
    
    //If we are hiding the statusbar we perform the below
    if(statusBarHidden==YES)
    {
        //Set our dialog to full screen 
        smsComposer.wantsFullScreenLayout = NO;  
        //Get the existing statusbar value so we can reset it later on
        statusBarHiddenOldValue = [UIApplication sharedApplication].statusBarHidden;
        //Set our status flag
        statusBarHiddenCheck =  YES;
    }

    //See if we need to do anything with the barColor
    UIColor * barColor = [[TiUtils colorValue:[self valueForUndefinedKey:@"barColor"]] _color];
    if (barColor != nil)
    {
        [[smsComposer navigationBar] setTintColor:barColor]; 
    }

    TiBlob* blob = [self valueForUndefinedKey:@"image"];
    
    NSString * imageName = [TiUtils stringValue:[self valueForUndefinedKey:@"imageName"]];
    
    NSLog(@"============MingChen===========> blob is %@", blob);
    
    if (blob && canSendAttachment) {
        
        NSLog(@"============MingChen===========> type is %d", blob.type);
        
        NSLog(@"============MingChen===========> image is %@", blob.image);
        
        [smsComposer addAttachmentData:UIImageJPEGRepresentation(blob.image, 1.0) typeIdentifier:@"public.image" filename:(imageName ? imageName : @"cardface.png")];
    }

    //If we are hiding the statusbar we need to do it after it is presented
    if(statusBarHidden==YES)
    {
        //We need to hide the statusbar for the full app
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        //[[[TiApp app] controller] resizeViewForStatusBarHidden:YES];
    }
    
    [self retain];
    
    //We call into core TiApp module this handles the controller magic for us        
    [[TiApp app] showModalController:smsComposer animated:showAnimated];
    
}

#pragma mark Delegate 
- (void)messageComposeViewController:(MFMessageComposeViewController *)smsComposer
                 didFinishWithResult:(MessageComposeResult)result
{
    BOOL animated = YES;
    NSString *eventName;
    NSString *msg;

    //If we enabled full screen, we need to set it back
    if(statusBarHiddenCheck==YES)
    {
        statusBarHiddenCheck=NO; //Reset our flag here
        //We set the statusbar value to what it was before we started
        [[UIApplication sharedApplication] setStatusBarHidden:statusBarHiddenOldValue];
    }
    
    //hide the dialog window (with animation)
	[[TiApp app] hideModalController:smsComposer animated:animated];
	[smsComposer autorelease];
	smsComposer = nil;

    
    if (result == MessageComposeResultCancelled)
    {
        eventName=@"cancelled";
        msg=@"Message was cancelled";
        
    }
    else if (result == MessageComposeResultSent)
    {
        eventName=@"completed";  
        msg=@"Message sent successfully";
    }
    else
    {
        eventName=@"errored";
        msg=@"Error sending message";
    }
    
    
    if ([self _hasListeners:eventName])
    {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               msg,@"message",
                               nil
                               ];
        
        [self fireEvent:eventName withObject:event];      
    }  

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([smsComposer respondsToSelector:@selector(dismissModalViewControllerAnimated:)])
    {

        [smsComposer dismissModalViewControllerAnimated:YES];
    }
#pragma clang diagnostic pop
    
	[self release];
}

@end

