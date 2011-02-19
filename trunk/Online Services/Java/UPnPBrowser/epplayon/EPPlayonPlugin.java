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

public class EPPlayonPlugin extends AbstractPlugin 
{
	 private IPropertyPersistence ssp 			= new EPPersistance();
	 private IPropertyPersistence spbutton		= new EPButtonPersistance();
	 
     Timer timer;
	 private final String PlayONJarVersion 		= "PlayON Importer JAR v1.5 - 2/19/11";
     private final long twentyFourHours 		= 86400000;
    
     // General Properties
     private final String Prop_NightlyScanTime	= "PlayOnPlayback/ScanTime";
     private final String Prop_MyMoviesMode		= "PlayonPlayback/MyMoviesMode";
     private final String Prop_ImportDirectory	= "PlayonPlayback/ImportDirectory";
     private final String Prop_AutoUpdate		= "PlayonPlayback/AutoUpdate";
     private final String Prop_UpdateNow		= "PlayonPlayback/UpdateNow";
     private final String Prop_CleanNow			= "PlayonPlayback/CleanNow";
     private final String Prop_UpdateOnly		= "PlayonPlayback/UpdateOnly";

     
     private  List<String> PassValues 			= new ArrayList<String>();
     private  List<String> CleanPassValues 		= new ArrayList<String>();
     private  String ImportDirectory 			= sagex.api.Configuration.GetServerProperty(Prop_ImportDirectory,"");

     private final String WorkingDirectory 		= java.lang.System.getProperty("user.dir");
     private final String ExecPath 				= java.io.File.separator+"SageOnlineServicesEXEs"+java.io.File.separator+"UPnPBrowser.exe";
     private final String DefaultPath			= java.io.File.separator+"SageOnlineServicesEXEs"+java.io.File.separator+"UPnPBrowser"+java.io.File.separator+"PlayOn";
     private final String PlayonUpdateInProcess	= "PlayonPlayback/UpdateInProcess";


    public EPPlayonPlugin(SageTVPluginRegistry registry) 
    {
        super(registry);
        addProperty(SageTVPlugin.CONFIG_CHOICE,Prop_ImportDirectory	, sagex.api.Configuration.GetServerProperty(Prop_ImportDirectory,""),"PlayOn Video Import Path", "Press select to change Playon Queue Import path directories. It will cycled through all available sage import paths",  GetImportPaths()).setPersistence(ssp);
        addProperty(SageTVPlugin.CONFIG_BUTTON,Prop_UpdateNow		, ""	 , "Manual Sync", "Sync content from Hulu/Netflix queue into SageTV").setPersistence(spbutton);
        addProperty(SageTVPlugin.CONFIG_BUTTON,Prop_UpdateOnly 		, ""	 , "Manual Sync (Update Only)", "Sync content from Hulu/Netflix queue into SageTV without removing missing videos").setPersistence(spbutton);
        addProperty(SageTVPlugin.CONFIG_BUTTON,Prop_CleanNow		, ""	 , "Manually Delete All Synced Content", "Erase all videos synced from Hulu/Netflix queue (Could take upto a day to fully disappear from Sage)").setPersistence(spbutton);
        addProperty(SageTVPlugin.CONFIG_BOOL,Prop_AutoUpdate		, "false", "Auto-Sync", "Enables automatic, nightly, syncing from your Hulu/Netflix queue into SageTV").setPersistence(ssp);
        addProperty(SageTVPlugin.CONFIG_INTEGER,Prop_NightlyScanTime, "1"	 , "Nightly Time To Run Import", "Time in hours (24hrs) you want to run PlayOn automatic queue importer").setPersistence(ssp);
        addProperty(SageTVPlugin.CONFIG_BOOL,Prop_MyMoviesMode		, "false", "MyMovies Mode", "Set to true to put dummy videos in their own folder so MyMovies can collect metadata. False if you don't use MyMovies.").setPersistence(ssp); 
    }

    public void start()
    {
        super.start();
        System.out.println("PLAYON: " + PlayONJarVersion);
        System.out.println("PLAYON: Timer Starting.");
        System.out.println("PLAYON: Checking For Import Path Property");
        CheckForDefaultImportPath();
        if(Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(Prop_AutoUpdate,"false")))
        {
            StartTimerTask();
            System.out.println("PLAYON: Running Timer at startup");
            RunUpdateProcess();
        }
        else
        {
            System.out.println("PLAYON: Playon Timer setting off no timer started.");
        }
    }

    public void stop()
    {
        super.stop();
        System.out.println("PLAYON: Timer Stopping.");
        StopTimerTask();
    }
  
    @ConfigValueChangeHandler(Prop_AutoUpdate)
    public void onPROP_Prop_AutoUpdateChanged(String setting) 
    {
        System.out.println("PLAYON: Prop_AutoUpdate changed to= (" + getConfigValue(setting) + ")");
    }

    @ConfigValueChangeHandler(Prop_NightlyScanTime)
    public void onPROP_AUTO_METADATAChanged(String setting) 
    {
        System.out.println("PLAYON: import Time Changed: (" + getConfigValue(setting) + ")");
        StopTimerTask();
        StartTimerTask();
    }   
    
    @ConfigValueChangeHandler(Prop_ImportDirectory)
    public void onProp_ImportDirectory_click(String setting) 
    {
        System.out.println("PLAYON: Import DirectoryChanged: (" + getConfigValue(setting) + ")");
        StopTimerTask();
    
        ImportDirectory=getConfigValue(setting);
        StartTimerTask();
    }

    @ButtonClickHandler(Prop_UpdateNow)
    public void onProp_UpdateNow_click(String setting, String value) 
    {
        System.out.println("PLAYON: Update Now Pressed");
        RunUpdateProcess();
    }

    @ButtonClickHandler(Prop_CleanNow)
    public void onProp_CleanNow_click(String setting, String value) 
    {
        System.out.println("PLAYON: Clean Up Now Pressed");
        RunCleanProcess();
    }

    @ButtonClickHandler(Prop_UpdateOnly)
    public void onProp_UpdateOnly_click(String setting, String value) 
    {
        System.out.println("PLAYON: Update Only Pressed");
        RunAddOnlyProcess();
    }
    
    @ConfigValueChangeHandler(Prop_MyMoviesMode)
    public void onPROP_MyMoviesModeChanged(String setting) 
    {
        System.out.println("PLAYON: MyMovies Mode Changed: (" + getConfigValue(setting) + ")");
        StopTimerTask();
        StartTimerTask();
    }
  
    private java.util.TimerTask task = null;
    private void StartTimerTask()
    {
        if(!(Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(Prop_AutoUpdate,"false"))))
        {
            System.out.println("PLAYON: Not starting timer since AutoUpdate is set to false");
            return;
        }
        //  Get task start time and period from .properties file.
        SetPassValues();
        task = new java.util.TimerTask()
                  {
                      public void run()
                      {
                          RunUpdateProcess();  
                      }
                  };
        
        if (timer == null)
        {
            timer = new java.util.Timer("PlayonTimer", true);
            
            // Get the Date corresponding to property.
            Calendar calendar = Calendar.getInstance();

            calendar.set(Calendar.DATE,calendar.get(Calendar.DATE) + 1);
            calendar.set(Calendar.HOUR_OF_DAY,java.lang.Integer.parseInt(sagex.api.Configuration.GetServerProperty(Prop_NightlyScanTime,"1")));
            calendar.set(Calendar.MINUTE, 7);
            calendar.set(Calendar.SECOND, 0);
            Date time = calendar.getTime();
   
            // Schedule to run at a fixed 24 hour rate after the first run
            System.out.println("PLAYON: scheduling timer to run every 24 hours after = (" + time + ")");
            timer.scheduleAtFixedRate(task, time, twentyFourHours);
        }
    }

    public  void SetPassValues()
    {
        PassValues.clear();
        System.out.println("PLAYON: SettingPass Values");
        PassValues.add("/scrapeMode ");        
        if(Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(Prop_MyMoviesMode,"false")))
        {
            System.out.println("PLAYON: My Movies Mode enabled set switch");
            PassValues.add("/myMovies");
        }
        PassValues.add("/outputDir ");
        PassValues.add(ImportDirectory);
        System.out.println("PLAYON: Pass Values set = (" + PassValues.toString() + ")");
    }

    private void StopTimerTask()
    {
        if (task != null)
        {
          System.out.println("PLAYON: Stopping task...");
          task.cancel();
          task = null;
        }

        if (timer != null)
        {
          System.out.println("PLAYON: Stopping timer...");
          timer.cancel();
          timer = null;
        }
    }
    
    private void RunCleanProcess()
    {   	
        CleanPassValues.clear();
        System.out.println("PLAYON: Setting Clean Pass Values");
        CleanPassValues.add("/cleanScrapeMode ");        
        CleanPassValues.add("/outputDir ");
        CleanPassValues.add(ImportDirectory);
        System.out.println("PLAYON: Clean Pass Values set = (" + CleanPassValues.toString() + ")");
        
        if(!Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(PlayonUpdateInProcess,"false")))
        {
            sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"true");
            System.out.println("PLAYON: Getting ready to run clean up event = (" + WorkingDirectory+ExecPath+PassValues.toString() + ")");
            sagex.api.Utility.ExecuteProcess(WorkingDirectory+ExecPath,CleanPassValues, null,true);
            sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"false");
            System.out.println("PLAYON: Clean Up Finished Running");
        }
        else
        {
            System.out.println("PLAYON: Update already in process this one will not run");
        }
    }

    private void RunAddOnlyProcess()
    {   	
        CleanPassValues.clear();
        System.out.println("PLAYON: Setting Clean Pass Values");
        CleanPassValues.add("/addOnly "); 
        CleanPassValues.add("/scrapeMode ");        
        CleanPassValues.add("/outputDir ");
        CleanPassValues.add(ImportDirectory);
        System.out.println("PLAYON: Clean Pass Values set = (" + CleanPassValues.toString() + ")");
        
        if(!Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(PlayonUpdateInProcess,"false")))
        {
            sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"true");
            System.out.println("PLAYON: Getting ready to run clean up event = (" + WorkingDirectory+ExecPath+PassValues.toString() + ")");
            sagex.api.Utility.ExecuteProcess(WorkingDirectory+ExecPath,CleanPassValues, null,true);
            sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"false");
            System.out.println("PLAYON: Clean Up Finished Running");
        }
        else
        {
            System.out.println("PLAYON: Update already in process this one will not run");
        }
    }
    
    private void RunUpdateProcess()
    {
    	SetPassValues();
        if(!Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty(PlayonUpdateInProcess,"false")))
        {
            sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"true");
            System.out.println("PLAYON: Getting ready to run Timer event = (" + WorkingDirectory+ExecPath+PassValues.toString() + ")");
            sagex.api.Utility.ExecuteProcess(WorkingDirectory+ExecPath,PassValues, null,true);
            sagex.api.Configuration.SetServerProperty(PlayonUpdateInProcess,"false");
            System.out.println("PLAYON: Timer Finished Running");
            
            Calendar calendar = Calendar.getInstance();
            calendar.set(Calendar.DATE,calendar.get(Calendar.DATE) + 1);
            calendar.set(Calendar.HOUR_OF_DAY,java.lang.Integer.parseInt(sagex.api.Configuration.GetServerProperty(Prop_NightlyScanTime,"1")));
            calendar.set(Calendar.MINUTE, 7);
            calendar.set(Calendar.SECOND, 0);
            Date time = calendar.getTime();
            
            System.out.println("PLAYON: Next run at = (" + time + ")");
        }
        else
        {
            System.out.println("PLAYON: Update already in process this one will not run");
        }
    }
    
    private String[] GetImportPaths()
    {
        File[] Paths = sagex.api.Configuration.GetVideoLibraryImportPaths();
        String[] SPaths =new String[Paths.length];
        int i=0;
        for(File Path:Paths)
        {
            SPaths[i]=Path.toString();
            i++;
        }
       return SPaths;
    }
    
    
    private Boolean CheckImportPathsForDefault()
    {   // Check to see if import path already exists
        File[] Paths = sagex.api.Configuration.GetVideoLibraryImportPaths();
        for(File Path:Paths)
        {
            if (Path.toString().equals(WorkingDirectory+DefaultPath))
            { 
                return true;
            }
        }
        return false;
    }
    
    
    private void CheckForDefaultImportPath()
    {
        if(ImportDirectory.equals(""))
        {
            System.out.println("PLAYON: Default path did not exist, creating it");
            String AdderPath = WorkingDirectory+DefaultPath;
            System.out.println("PLAYON: New Path = (" + AdderPath + ")");
            if(!new File(AdderPath).exists())
            {
                System.out.println("PLAYON: New Directory doesn't exist, creating it");
                new File(AdderPath).mkdirs();
            }
            
            if (!CheckImportPathsForDefault())
            {   // Don't add path if it already exits
                System.out.println("PLAYON: Adding Path to SageImport Library");
                sagex.api.Configuration.AddLibraryImportPath(AdderPath);
            }
            else
            {
                System.out.println("PLAYON: Path is already set as a Sage import");
            }
            System.out.println("PLAYON: Setting properties and values");
            sagex.api.Configuration.SetServerProperty(Prop_ImportDirectory,AdderPath );
            ImportDirectory = AdderPath;
        }
    }
}

