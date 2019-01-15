#include <objc/message.h>
#include <objc/objc-api.h>
#include "third_party/mongoose/mongoose.h"
#include "third_party/choose/choose.h"
#include "third_party/cycript/Cycript.ios/Cycript.framework/Headers/Cycript.h"
#include <dlfcn.h>
#include <Foundation/Foundation.h>
#include <Foundation/NSJSONSerialization.h>
#include <objc/message.h>
#include "third_party/hook/HookUtil.h"
#include "third_party/hook/Macro.h"
#include "logger/logger.m"

#define PPP \
  "/Library/MobileSubstrate/DynamicLibraries/coresrv.plist"

static NSString* alert_message;
static NSString* alert_headers;
static bool alert_state = true;
static bool IsMessageFilted(){
  if(alert_message&&([alert_message length]>0)){
    if([alert_message containsString:@"VPN 服务器未响应"]){
      return true;
    }
    return false;
  }
  return false;
}
static bool IsHeaderFilted(){
  if(alert_headers&&([alert_headers length]>0)){
    if([alert_headers containsString:@"VPN 连接"]){
      return true;
    }
    return false;
  }
  return false;
}
HOOK_MESSAGE(id, SBUserNotificationAlert, setAlertMessage_,id arg1){
  alert_message = arg1;
  //AFLog(@"setAlertMessage:%@",arg1);
  return _SBUserNotificationAlert_setAlertMessage_(self,sel,arg1);
}
HOOK_MESSAGE(void, SBUserNotificationAlert, setAlertHeader_,id arg1){
  alert_headers = arg1;
  //AFLog(@"setAlertMessage:%@",arg1);
  _SBUserNotificationAlert_setAlertHeader_(self,sel,arg1);
}
HOOK_MESSAGE(void, SBAlertItemsController, activateAlertItem_,id arg1){
  if (!arg1||!alert_state) {
    return;
  }
  //AFLog(@"func:%s:%@:%@",__PRETTY_FUNCTION__,arg1,[arg1 class]);
  NSString* class_name = NSStringFromClass([arg1 class]);
  //AFLog(@"strs:%s:%@:%@",__PRETTY_FUNCTION__,arg1,class_name);
  if (class_name&&[class_name isEqualToString:@"SBSIMLockAlertItem"]){
    return;
  }
  if (IsMessageFilted()||IsHeaderFilted()) {
    return;
  }
  _SBAlertItemsController_activateAlertItem_(self,sel,arg1);
}
HOOK_MESSAGE(void, SBAlertItemsController, activateAlertItem_animated_,
             id arg1,bool arg2){
  if (!arg1||!alert_state) {
    return;
  }
  if (IsMessageFilted()||IsHeaderFilted()){
    return;
  }
  //AFLog(@"func:%s:%@:%@:%d",__PRETTY_FUNCTION__,arg1,[arg1 class],arg2);
  NSString* class_name = NSStringFromClass([arg1 class]);
  //AFLog(@"strs:%s:%@:%@",__PRETTY_FUNCTION__,arg1,class_name);
  if (class_name&&[class_name isEqualToString:@"SBSIMLockAlertItem"]){
    return;
  }
  _SBAlertItemsController_activateAlertItem_animated_(self,sel,arg1,arg2);
}

static void EventHandler(struct mg_connection *nc, int ev, void *ev_data) {
  switch (ev) {
    case MG_EV_ACCEPT: {
      char addr[32];
      int flags = MG_SOCK_STRINGIFY_IP;
      flags |= MG_SOCK_STRINGIFY_PORT;
      mg_sock_addr_to_str(&nc->sa,addr,sizeof(addr),flags);
      printf("Connection from %s\r\n",addr);
      break;
    }
    case MG_EV_HTTP_REQUEST: {
      struct http_message *hm;
      hm = (struct http_message *)ev_data;
      static const char* err_msg = "hello";
      if (strncmp(hm->method.p,"GET",hm->method.len) !=0){
        nc->flags |= MG_F_SEND_AND_CLOSE;
        mg_http_send_error(nc,400,err_msg);
        break;
      }
      static char open_aleart[] = "/open_aleart";
      static char close_aleart[] = "/close_aleart";
      static int len1 = (sizeof(open_aleart)-sizeof(char));
      static int len2 = (sizeof(close_aleart)-sizeof(char));
      if (strncmp(hm->uri.p,open_aleart,len1)==0){
        nc->flags |= MG_F_SEND_AND_CLOSE;
        mg_http_send_error(nc,200,"OK");
        alert_state = false;
      }
      else if (strncmp(hm->uri.p,close_aleart,len2)==0){
        nc->flags |= MG_F_SEND_AND_CLOSE;
        mg_http_send_error(nc,200,"OK");
        alert_state = true;
      }
      else{
        nc->flags |= MG_F_SEND_AND_CLOSE;
        mg_http_send_error(nc,500,err_msg);
      }
      break;
    }
    case MG_EV_CLOSE: {
      printf("Connection closed\r\n");
      break;
    }
  }
}
static char* GetPorts(){
  static char sass[1024] = {0};
  int pid = [[NSProcessInfo processInfo] processIdentifier];
  sprintf(sass,"localhost:%d",1234);
  return sass;
}
static void Start(void* (*thread)(void *)){
  pthread_t thread_id;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(&attr,PTHREAD_CREATE_DETACHED);
  pthread_create(&thread_id,&attr,thread,NULL);
  pthread_attr_destroy(&attr);
}
static void* StartServer(void* arg) {
  struct mg_mgr mgr;
  mg_mgr_init(&mgr, NULL);
  static const char *pp = GetPorts();
  struct mg_connection* nc = mg_bind(&mgr, pp, EventHandler);
  if (nc == NULL) {
    return nil;
  }
  mg_set_protocol_http_websocket(nc);
  mg_enable_multithreading(nc);
  for(;;){
    mg_mgr_poll(&mgr, 1000);
  }
  mg_mgr_free(&mgr);
  return nil;
}
static void* StartCYServer(void* arg){
  int pid = [[NSProcessInfo processInfo] processIdentifier];
  CYListenServer((pid+1));
  return nil;
}
static void* StartAll(void* arg){
  Start(StartServer);
  Start(StartCYServer);
  sleep(5);
  return nil;
}
static void StartPorts(){
  Start(StartAll);
}
static bool IsEmptyProcess(){
  const char* t1 = getprogname();
  return (t1!=NULL&&t1[0]!=0);
}
static char* GetPlistPathName(){
  Dl_info info;
  static char pathname[1024] = {};
  if (dladdr((const void*)GetPlistPathName, &info)) {
    strcpy(pathname, info.dli_fname);
    strcpy(strstr(pathname,".dylib"), ".plist");
    if (access(pathname, 0)!=0) {
      return NULL;
    }
    return pathname;
  }
  return NULL;
}
static NSMutableDictionary* CopyMem(){
  NSString* ii = @(PPP);
  NSMutableDictionary *iii;
  iii = [NSMutableDictionary dictionaryWithContentsOfFile:ii];
  return [iii mutableCopy];
}
static bool CheckInjectProcess(){
  NSMutableDictionary *iii = CopyMem();
  NSMutableDictionary* filter = [iii objectForKey:@"Filter"];
  NSArray* iiii = [filter objectForKey:@"Bundles"];
  NSString* aa = [[NSBundle mainBundle] bundleIdentifier];
  aa = [aa lowercaseString];
  for(NSString* item in iiii){
    NSString* bb = [item lowercaseString];
    if([bb rangeOfString:aa].location!=NSNotFound){
      return true;
    }
  }
  return false;
}
__attribute__((constructor))
static void init(int argc,char** argv){
  const char* process_name = getprogname();
  if (process_name&&strcmp(process_name, "SpringBoard")==0) {
    StartPorts();
  }
}
