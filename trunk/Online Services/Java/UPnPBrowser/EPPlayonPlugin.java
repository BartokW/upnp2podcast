package epplayon;






import java.io.File;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.Timer;
import sage.SageTVPlugin;
import sage.SageTVPluginRegistry;
import sagex.plugin.AbstractPlugin;
import sagex.plugin.ButtonClickHandler;
import sagex.plugin.ConfigValueChangeHandler;
import sagex.plugin.IPropertyPersistence;
public class EPPlayonPlugin extends AbstractPlugin {

     private IPropertyPersistence ssp = new EPPersistance();
     private IPropertyPersistence spbutton= new EPButtonPersistance();
         Timer timer;
         private final String Prop_NightlyScanTime= "PlayOnPlayback/ScanTime";
         private final String Prop_MyMoviesMode= "PlayonPlayback/MyMoviesMode";
         private final String Prop_ImportDirectory="PlayonPlayback/ImportDirectory";
         private final String Prop_AutoUpdate="PlayonPlayback/AutoUpdate";
         private final String Prop_UpdateNow="";
         private  List<String> PassValues = new ArrayList<String>();
         private  String ImportDirectory = sagex.api.Configuration.GetServerProperty(Prop_ImportDirectory,"");

         private final String WorkingDirectory = java.lang.System.getProperty("user.dir");
         private final String ExecPath ="\\SageOnlineServicesEXEs\\UPnPBrowser.exe";
         private final String DefaultPath="\\SageOnlineServicesEXEs\\UPnPBrowser\\PlayOn";
         private final String PlayonUpdateInProcess="PlayonPlayback/UpdateInProcess";


//    public SMMPlugin pluginInstance = null;

//             public  SMMPlugin getPluginInstance() {
//                 return pluginInstance;
//         }

             public EPPlayonPlugin(SageTVPluginRegistry registry) {
                 super(registry);

                addProperty(SageTVPlugin.CONFIG_INTEGER,Prop_NightlyScanTime, "1", "NightlyTimeToRunImport", "Time in hours (24hrs) you want to run the automatic update.").setPersistence(ssp);
                 addProperty(SageTVPlugin.CONFIG_BOOL,Prop_MyMoviesMode, "false", "MyMovies Mode", "Set to true to put dummy videos in their own folder so MyMovies can collect metadata. False if you don't use MyMovies.").setPersistence(ssp);
                 addProperty(SageTVPlugin.CONFIG_BOOL,Prop_AutoUpdate, "true", "PlayOn AutoUpdate", "Set to true to have Playon auto update/download videos at set time. False to not auto update.").setPersistence(ssp);
                 addProperty(SageTVPlugin.CONFIG_BUTTON,Prop_UpdateNow, "", "Update PlayonVideos", "Press to Update Playon Videos now.").setPersistence(spbutton);
                 addProperty(SageTVPlugin.CONFIG_CHOICE,Prop_ImportDirectory, sagex.api.Configuration.GetServerProperty(Prop_ImportDirectory,""),"PlayOn Import Path", "Press select to change Playon Import path directories. It will cycled through all available sage import paths",  GetImportPaths()).setPersistence(ssp);

         }




    public void start(){
        super.start();
          System.out.println("Playon Timer Starting.");
          System.out.println("Playon Checking For Import Path Property");
          CheckForDefaultImportPath();
//          if(ImportDirectory.equals("")){
//          System.out.println("Playon Import path not set yet.");
//          sagex.api.Configuration.SetServerProperty(Prop_ImportDirectory,sagex.api.Configuration.GetVideoLibraryImportPaths()[0].toString());}
        if(Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(Prop_AutoUpdate,"true")))
        {
          StartTimerTask();
          System.out.println("Playon Timer finished setting task.");
          // SZ
          System.out.println("Running Timer at startup");
          RunUpdateProcess();
        }
        else{
          System.out.println("Playon Timer setting off no timer started.");}
        }

    public void stop(){
        super.stop();
        System.out.println("Playon Timer Stopping.");
        StopTimerTask();
        }

    @ConfigValueChangeHandler(Prop_NightlyScanTime)
	public void onPROP_AUTO_METADATAChanged(String setting) {
		System.out.println("Playon import Time Changed: " + getConfigValue(setting));
                StopTimerTask();
                StartTimerTask();
	}

    @ConfigValueChangeHandler(Prop_AutoUpdate)
	public void onPROP_Auto_UpdateChanged(String setting) {
		System.out.println("Playon Auto Update changed to= " + getConfigValue(setting));
                StopTimerTask();
                if(Boolean.parseBoolean(getConfigValue(setting))){
                StartTimerTask();}
	}

    @ConfigValueChangeHandler(Prop_ImportDirectory)
	public void onProp_ImportDirectory_click(String setting) {
		System.out.println("Playon Import DirectoryChanged: " + getConfigValue(setting));
                StopTimerTask();

                ImportDirectory=getConfigValue(setting);
                StartTimerTask();
	}



    @ButtonClickHandler(Prop_UpdateNow)
	public void onProp_UpdateNow_click(String setting, String value) {
        System.out.println("Playon Update Now Pressed");
        RunUpdateProcess();}

    




    

     @ConfigValueChangeHandler(Prop_MyMoviesMode)
	public void onPROP_MyMoviesModeChanged(String setting) {
		System.out.println("Playon MyMovies Mode Changed: " + getConfigValue(setting));
                StopTimerTask();
                StartTimerTask();
	}

  
    private java.util.TimerTask task = null;

    private void StartTimerTask()
        {
    //  Get task start time and period from .properties file.
         SetPassValues();
        task = new java.util.TimerTask()
            {
            public void run()
                {
            RunUpdateProcess();  }
            };
        
        if (timer == null){
            timer = new java.util.Timer("PlayonTimer", true);
            // Get the Date corresponding to property.
            Calendar calendar = Calendar.getInstance();
            
            // SZ
            // Set the first run for the next day
            calendar.set(Calendar.DATE,calendar.get(Calendar.DATE) + 1);
            
            calendar.set(Calendar.HOUR_OF_DAY,java.lang.Integer.parseInt(sagex.api.Configuration.GetServerProperty(Prop_NightlyScanTime,"1")));
            calendar.set(Calendar.MINUTE, 0);
            calendar.set(Calendar.SECOND, 0);
            Date time = calendar.getTime();
   
            // SZ
            // Schedule to run at a fixed 24 hour rate after the first run
            System.out.println("Playon starting timer to run every 24 hours after = "+time);
            timer.scheduleAtFixedRate(task, time, 86400000);}

     
        }

    public  void SetPassValues(){
        PassValues.clear();
     System.out.println("SettingPass Values");
    PassValues.add("/scrapeMode ");
    PassValues.add("/outputDir ");

    if(Boolean.parseBoolean( Prop_MyMoviesMode)){
   System.out.println("My Movies Mode enabled set switch");
    PassValues.add("/myMovies");}
     PassValues.add(ImportDirectory);
      System.out.println("Pass Values set ="+PassValues.toString());

    }

    private void StopTimerTask()
        {
        if (task != null)
            {
            System.out.println("Playon stopping timer");
            task.cancel();
            task = null;
            }
        }

    private void RunUpdateProcess(){
      if(!Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(PlayonUpdateInProcess,"false"))){
      sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"true");
     System.out.println("Playon getting ready to run Timer event="+WorkingDirectory+ExecPath+PassValues.toString());
            sagex.api.Utility.ExecuteProcess(WorkingDirectory+ExecPath,PassValues, null,true);
     sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"false");
              System.out.println("Playon Timer Finished Running");}
      else{
       System.out.println("Playon Update already in process this one will not run");}
    }
    
    private String[] GetImportPaths(){
    File[] Paths = sagex.api.Configuration.GetVideoLibraryImportPaths();
    String[] SPaths =new String[Paths.length];
    int i=0;
    for(File Path:Paths){
    SPaths[i]=Path.toString();
    i++;}
    return SPaths;}

    private void CheckForDefaultImportPath(){
    if(ImportDirectory.equals("")){
    System.out.println("Playon default path did not exist creating");
    String AdderPath = WorkingDirectory+DefaultPath;
    System.out.println("Playon New Path="+AdderPath);
    if(!new File(AdderPath).exists()){
    System.out.println("Playon New Directory did not exist creating");
    new File(AdderPath).mkdirs();}
    System.out.println("Playon Adding Path to SageImport Library");
    sagex.api.Configuration.AddLibraryImportPath(AdderPath);
    System.out.println("Path Added now setting properties and values");
    sagex.api.Configuration.SetServerProperty(Prop_ImportDirectory,AdderPath );
    ImportDirectory = AdderPath;
    }}

}

