#import <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>

%hook UIAlertController
+ (id)alertControllerWithTitle:(id)arg1 message:(id)arg2 preferredStyle:(int)arg3{
  return nil;
}
%end

%ctor
{
	%init;
}
