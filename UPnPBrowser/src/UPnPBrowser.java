package PlayOnForSageTV;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.teleal.cling.UpnpService;
import org.teleal.cling.UpnpServiceImpl;
import org.teleal.cling.model.action.ActionInvocation;
import org.teleal.cling.model.meta.LocalDevice;
import org.teleal.cling.model.meta.RemoteDevice;
import org.teleal.cling.model.meta.RemoteService;
import org.teleal.cling.model.message.UpnpResponse;
import org.teleal.cling.model.message.header.STAllHeader;
import org.teleal.cling.registry.RegistryListener;
import org.teleal.cling.registry.Registry;
import org.teleal.cling.support.contentdirectory.callback.Browse;
import org.teleal.cling.support.model.BrowseFlag;
import org.teleal.cling.support.model.DIDLContent;
import org.teleal.cling.support.model.DIDLObject.Property;
import org.teleal.cling.support.model.Res;
import org.teleal.cling.support.model.container.Container;
import org.teleal.cling.support.model.item.Item;

/**
 * Simple function for grabbing UPnP Media Server Paths
 * <p>
 * Call this class from the command-line to quickly evaluate Cling, it will
 * search for all UPnP devices on your LAN and print out any discovered, added,
 * and removed devices while it is running.
 * </p>
 * 
 * @author Scott Zadigian zadigian(at)gmail(dot)com
 */
public class UPnPBrowser {
	// UPnP Variables
	static UpnpService gUPnPService = null;
	static String gRemoteDeviceString = "";
	static RemoteDevice gRemoteDevice = null;
	static RemoteService gRemoteService = null;
	static List<Container> gCurrentContainers = null;
	static List<Item> gCurrentItems = null;
	static HashMap<String, RemoteDevice> gUPnPDevices = new HashMap<String, RemoteDevice>();

	// MAIN
	@SuppressWarnings("unused")
	public static void main(String[] args) throws Exception {
		// Return Object
		Vector<HashMap<String, String>> returnList = null;
		HashMap<String,HashMap<String, String>> returnHash = null; // Temp
		String UID = "";
		String StaticPath = "";
		String UPnPDeviceRegEx = "playon";
		
		// Test #1: Get list of all UPnP Devices
		System.out.println("====================   TEST #1 ====================");
		returnList = new Vector<HashMap<String, String>>();
		int SearchTime = 5;
		getUPnPDeviceList(returnList,SearchTime);
		System.out.println("  + Found UPnP Servers");
		for (HashMap<String, String> device:returnList){
			System.out.println("    - (" + device.get("UPnPDevice") + ")");			
			// Set Device for next test
			if (device.get("UPnPDevice").contains("PlayOn")){
				UPnPDeviceRegEx = device.get("UPnPDevice");
			}				
		}
	
		// Test #2: Get all items at a given path w/o initial UID	
		System.out.println("====================   TEST #2 ====================");
		returnList = new Vector<HashMap<String, String>>();
		String Path = "Netflix::Instant Queue::Queue Top 50";
		int Depth = 1;
		getUPnPDirectoryForPath(returnList, UPnPDeviceRegEx, Path, Depth);
		printSortedHash(returnList);

		// Grab a UID and Static path for test #2
		for (HashMap<String, String> item:returnList){
			if (isFolder(item)) {
				UID = item.get("Directory");
				StaticPath = item.get("Path") + "::" + item.get("Title");
			}
		}
		
		 // Test #3: Get all items at a given path WITH initial UID 
		System.out.println("====================   TEST #3 ====================");
		returnList = new Vector<HashMap<String, String>>();
		Depth = 2;
		getUPnPDirectoryForUID(returnList, UPnPDeviceRegEx, UID, StaticPath, Depth);
		printSortedHash(returnList);
			
		 // Test #4: Get Single Media Object
		System.out.println("====================   TEST #4 ====================");
		returnHash = new HashMap<String, HashMap<String, String>>();
		String Fullpath = UPnPDeviceRegEx + "::Netflix::Instant Queue::Queue Top 50::Psych::Season 1::01: Pilot";
		returnList = new Vector<HashMap<String, String>>();
		getUPnPMediaForPath(returnList, Fullpath);
		printSortedHash(returnList);	
	}

	/*****************************
	 * Public Functions
	 *****************************/
	public static String version(){
		System.out.println("UPnPBrowser: Version v3.0");
		return "UPnPBrowser: Version v3.0";
	}
	
	// Start at root, navigate to path, store results in supplied hash
	public static void getUPnPMediaForPath(
			Vector<HashMap<String, String>> returnList, String Path)
			throws InterruptedException {
		long start = System.currentTimeMillis();
		String pathRegEx = "";
		String CurrentUID = "0"; // Always start at root for UPnPSearchByPath
		Queue<String> UPnPPath = new LinkedList<String>();
		System.out.println("Starting UPnPSearchByPath");
		System.out.println("  + Checking Parameters");
		// Split path and put in queue
		for (String path : Path.split("::")) {
			UPnPPath.offer(path);
		}
		System.out.println("    - Path        : (" + Path + ")(" + UPnPPath.size() + " elements)");
		
		// Set the UPnPDevice
		String UPnPDeviceRegEx = UPnPPath.poll();
		String CurrentPath = "";
		if (setUPnPDevice(java.util.regex.Pattern.quote(UPnPDeviceRegEx))) {
			while (UPnPPath.size() != 1 && CurrentUID != "") {
				pathRegEx = UPnPPath.poll();
				System.out.println("  + Searching for (" + pathRegEx + ") in (" + CurrentPath + ")(" + CurrentUID + ")");
				CurrentUID = searchUIDForPath(CurrentUID, pathRegEx);
				if (CurrentUID.equals("")) {
					System.out.println("!!! Couldn't find Path (" + CurrentPath + "::" + pathRegEx + ")");
					System.out.println("  + UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
					gUPnPService.shutdown();
					return;
				}
				if (CurrentPath.equals("")) {
					CurrentPath = pathRegEx;
				} else {
					CurrentPath = CurrentPath + "::" + pathRegEx;
				}
				
			}
			
			String MediaFile = UPnPPath.poll();
			System.out.println("    - Getting Items from : (" + CurrentPath + ")");
			getContentForUID(CurrentUID);
			List<Item> localItems = gCurrentItems;
			
			for (Item item : localItems) {
				// Put in Path and ParentUID
				HashMap<String, String> KeyValue = new HashMap<String, String>();
				KeyValue.put("Path", CurrentPath);
				KeyValue.put("UIDTitle", item.getTitle());
				KeyValue.put("ParentUID", CurrentUID);
				KeyValue.put("UPnPDevice", gRemoteDeviceString);

				for (Res metaData : item.getResources()) {
					KeyValue.put("Media", metaData.getValue().toString());
					KeyValue.put("Duration", metaData.getDuration());
					KeyValue.put("Size", metaData.getSize().toString());
				}
				for (Property metaData : item.getProperties()) {
					KeyValue.put(metaData.getDescriptorName(), metaData.getValue().toString());
				}
				if (item.getTitle().equalsIgnoreCase(MediaFile)) {
					System.out.println("  + Found (" + CurrentPath + "::" + item.getTitle() + ")");
					returnList.add(KeyValue);	
				}						
			}			
		} else {
			System.out.println("! Couldn't Find UPnP Device (" + UPnPDeviceRegEx + ")");
		}

		gUPnPService.shutdown();
		System.out.println("UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
		return;
	}

	
	// Start at root, navigate to path, store results in supplied hash
	public static void getUPnPDirectoryForPath(
			Vector<HashMap<String, String>> returnList,
			String UPnPDeviceRegEx, String Path, int Depth)
			throws InterruptedException {
		long start = System.currentTimeMillis();
		String pathRegEx = "";
		String CurrentUID = "0"; // Always start at root for UPnPSearchByPath
		String CurrentPath = UPnPDeviceRegEx;
		Queue<String> UPnPPath = new LinkedList<String>();
		System.out.println("Starting UPnPSearchByPath");
		System.out.println("  + Checking Parameters");
		// Split path and put in queue
		for (String path : Path.split("::")) {
			UPnPPath.offer(path);
		}
		System.out.println("    - UPnP Device : (" + UPnPDeviceRegEx + ")");
		System.out.println("    - Path        : (" + Path + ")(" + UPnPPath.size() + " elements)");
		System.out.println("    - Depth       : (" + Depth + ")");

		// Set the UPnPDevice
		if (setUPnPDevice(java.util.regex.Pattern.quote(UPnPDeviceRegEx))) {
			while (!UPnPPath.isEmpty() && !UPnPPath.peek().equals("")&& CurrentUID != "") {
				pathRegEx = UPnPPath.poll();
				System.out.println("  + Searching for (" + pathRegEx + ") in (" + CurrentPath + ")(" + CurrentUID + ")");
				CurrentUID = searchUIDForPath(CurrentUID, pathRegEx);
				if (CurrentUID.equals("")) {
					System.out.println("!!! Couldn't find Path (" + CurrentPath + "::" + pathRegEx + ")");
					System.out.println("  + UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
					gUPnPService.shutdown();
					return;
				}
				CurrentPath = CurrentPath + "::" + pathRegEx;
			}
			getContentForUID(returnList, CurrentUID, Path, Depth);
		} else {
			System.out.println("! Couldn't Find UPnP Device (" + UPnPDeviceRegEx + ")");
		}

		gUPnPService.shutdown();
		System.out.println("UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
		return;
	}

	// Get the UPnP Directory for a given UID and Server RegEx
	public static void getUPnPDirectoryForUID(
			Vector<HashMap<String, String>> returnList,
			String UPnPDeviceRegEx, String UID, String Path, int Depth)
			throws InterruptedException {
		long start = System.currentTimeMillis();
		System.out.println("Starting getUPnPDirectoryForUID");
		System.out.println("  + Checking Parameters");
		System.out.println("    - UPnP Device : (" + UPnPDeviceRegEx + ")");
		System.out.println("    - UID         : (" + UID + ")");
		System.out.println("    - Path        : (" + Path + ")");
		System.out.println("    - Depth       : (" + Depth + ")");

		// Set the UPnPDevice
		if (setUPnPDevice(java.util.regex.Pattern.quote(UPnPDeviceRegEx))) {
			getContentForUID(returnList, UID, Path, Depth);
		} else {
			System.out.println("! Couldn't Find UPnP Device (" + UPnPDeviceRegEx + ")");
		}

		gUPnPService.shutdown();
		System.out.println("UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
		return;
	}

	// Get the UPnP Directory for a given UID and Server RegEx
	public static void getUPnPDeviceList(
			Vector<HashMap<String, String>> returnList,
			int SearchTimeInSec)
			throws InterruptedException {
		long start = System.currentTimeMillis();
		System.out.println("Starting getUPnPDeviceList");
		System.out.println("  + Checking Parameters");
		System.out.println("    - Search Time : (" + SearchTimeInSec  + " seconds)");
		
		// Sleep while looking for servers
		System.out.println("  + Looking For UPnP Devices");
		getUPnPServers();
		Thread.sleep(SearchTimeInSec * 1000);
		
		for (String deviceName : gUPnPDevices.keySet()) {
			HashMap<String, String> KeyValue = new HashMap<String, String>();
			KeyValue.put("UPnPDevice", deviceName);
			KeyValue.put("Path", deviceName);
			KeyValue.put("Directory", "0");
			KeyValue.put("ParentUID", "0");
			returnList.add(KeyValue);			
		}

		gUPnPService.shutdown();
		System.out.println("UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
		return;
	}
	
	/*****************************
	 * Private Functions
	 *****************************/
	// Get Content (items/containers) for a given UID
	private static void getContentForUID(String UID) {
		// Clear these fields before search
		Browse BrowseTree = new Browse(gRemoteService, UID, BrowseFlag.DIRECT_CHILDREN) {
			@Override
			public void received(ActionInvocation arg0, DIDLContent arg1) {
				gCurrentContainers = arg1.getContainers();
				gCurrentItems = arg1.getItems();
			}

			@Override
			public void updateStatus(Status arg0) {
			}

			@Override
			public void failure(ActionInvocation arg0, UpnpResponse arg1,
					String arg2) {
				System.out.println("! failure (" + arg2.toString() + ")");
			}
		};
		// Have 5 retrys
		for (int i = 0; i < 5 || gCurrentContainers == null; i++) {
			BrowseTree.setControlPoint(gUPnPService.getControlPoint());
			BrowseTree.run();
		}
	}

	// Recurive function for getting all UPnP items for a given UID and depth
	private static void getContentForUID(
			Vector<HashMap<String, String>> returnList, String UID,
			String Path, int Depth) {
		System.out.println("    - Getting Items from : (" + Path + ")(" + Depth + ")(" + UID + ")");
		getContentForUID(UID);
		List<Container> localContainers = gCurrentContainers;
		List<Item> localItems = gCurrentItems;

		for (Item item : localItems) {
			// Put in Path and ParentUID
			HashMap<String, String> KeyValue = new HashMap<String, String>();
			KeyValue.put("Path", Path);
			KeyValue.put("UIDTitle", item.getTitle());
			KeyValue.put("ParentUID", UID);
			KeyValue.put("UPnPDevice", gRemoteDeviceString);
			
			
			//System.out.println("      + Checking For TV shows ("+Path+"::"+item.getTitle()+")");
			// Hulu type #1
			String SERegEx= "([^\\-]+) - s([0-9]+)e([0-9]+): (.*)$";
			Pattern pattern = Pattern.compile(SERegEx);
			Matcher matcher = pattern.matcher(Path+"::"+item.getTitle());
			if (matcher.find()) {
				System.out.println("      + Detected TV Show (Hulu type #1)! ("+Path+"::"+item.getTitle()+")");
				KeyValue.put("TV", "true");
				KeyValue.put("Title", matcher.group(1));
				KeyValue.put("Season", matcher.group(2));
				KeyValue.put("Episode", matcher.group(3));
				KeyValue.put("EpisodeTitle", matcher.group(4));
			} else {
				// Hulu type #2
				SERegEx =  "([^:]+)::Full Episodes::s([0-9]+)e([0-9]+): (.*)";
				pattern = Pattern.compile(SERegEx);
				matcher = pattern.matcher(Path+"::"+item.getTitle());
				if (matcher.find()){
					System.out.println("      + Detected TV Show (Hulu type #2)! ("+Path+"::"+item.getTitle()+")");
					KeyValue.put("TV", "true");
					KeyValue.put("Title", matcher.group(1));
					KeyValue.put("Season", matcher.group(2));
					KeyValue.put("Episode", matcher.group(3));
					KeyValue.put("EpisodeTitle", matcher.group(4));					
				}
				else {
					// Netflix type #1
					SERegEx =  "([^:]+)::Season ([0-9]+)::([0-9]+): (.*)";
					pattern = Pattern.compile(SERegEx);
					matcher = pattern.matcher(Path+"::"+item.getTitle());
					if (matcher.find()){
						System.out.println("      + Detected TV Show (Netflix type #1)! ("+Path+"::"+item.getTitle()+")");
						KeyValue.put("TV", "true");
						KeyValue.put("Title", matcher.group(1));
						KeyValue.put("Season", matcher.group(2));
						KeyValue.put("Episode", matcher.group(3));
						KeyValue.put("EpisodeTitle", matcher.group(4));					
					} else {
						KeyValue.put("Title", item.getTitle());
					}
						
				}
			}
			
			for (Res metaData : item.getResources()) {
				KeyValue.put("Media", metaData.getValue().toString());
				KeyValue.put("Duration", metaData.getDuration());
				KeyValue.put("Size", metaData.getSize().toString());
			}
			for (Property metaData : item.getProperties()) {
				KeyValue.put(metaData.getDescriptorName(), metaData.getValue()
						.toString());
			}
			returnList.add(KeyValue);
		}

		// Folders
		for (Container container : localContainers) {
			if (Depth <= 1) {
				HashMap<String, String> KeyValue = new HashMap<String, String>();
				KeyValue.put("Path", Path);
				KeyValue.put("UIDTitle", container.getTitle());
				KeyValue.put("Title", container.getTitle());
				KeyValue.put("ParentUID", UID);
				KeyValue.put("Directory", container.getId());
				KeyValue.put("UPnPDevice", gRemoteDeviceString);
				returnList.add(KeyValue);
			} else {
				getContentForUID(returnList, container.getId(), Path + "::"
						+ container.getTitle(), Depth - 1);
			}
		}
	}

	// Search a UID for given Path
	private static String searchUIDForPath(String UID, String PathRegEx) {
		// Clear these fields before search
		String returnUID = "";
		getContentForUID(UID);

		// Search for folder
		for (Container container : gCurrentContainers) {
			if (Pattern.compile(PathRegEx).matcher(container.getTitle()).find()) {
				System.out.println("    *** FOLDER: (" + container.getTitle()
						+ ")(" + container.getId() + ")");
				returnUID = container.getId();
			}
		}
		return returnUID;
	}

	// Get UPnP Server for given RegEx
	private static boolean setUPnPDevice(String UPnPDeviceRegEx)
			throws InterruptedException {

		getUPnPServers();
		System.out.println("  + Looking for (" + UPnPDeviceRegEx + ") Device");
		// Recheck every 5 seconds to see if we've found the UPnPDevice
		for (int i = 0; !checkUPnPDeviceNameRegEx(UPnPDeviceRegEx) && i < 20; i++) {
			System.out.println("    - Attempt #" + i);
			Thread.sleep(500);
		}
		
		if (checkUPnPDeviceNameRegEx(UPnPDeviceRegEx)){
			System.out.println("    + Found (" + UPnPDeviceRegEx + ")!");
		}

		return checkUPnPDeviceNameRegEx(UPnPDeviceRegEx);
	}

	// Set the global UPnP Device and Service using given Regex
	private static boolean checkUPnPDeviceNameRegEx(String RegExToCheck)
			throws InterruptedException {
		// Pattern.compile(RegExToCheck).matcher(StringToCheck).find()
		Pattern pattern = Pattern.compile(RegExToCheck);
		for (String deviceName : gUPnPDevices.keySet()) {
			if (pattern.matcher(deviceName).find()) {
				gRemoteDevice = gUPnPDevices.get(deviceName);
				gRemoteDeviceString = deviceName;
				for (RemoteService service : gRemoteDevice.getServices()) {
					if (service.getServiceType().getType().equals("ContentDirectory")) {
						gRemoteService = service;
						return true;
					}
				}
			}
		}
		return false;
	}

	// Get UPnP Servers and put into global UPnPDevices hash
	private static void getUPnPServers() {
		gUPnPService = new UpnpServiceImpl(new RegistryListener() {
			@Override
			public void remoteDeviceAdded(Registry registry, RemoteDevice device) {
				System.out.println("! Found Device (" + device.getDetails().getFriendlyName() + ")(" + device.getDisplayString() + ")");
				gUPnPDevices.put(device.getDetails().getFriendlyName(), device);
			}

			@Override
			public void remoteDeviceDiscoveryFailed(Registry arg0, RemoteDevice arg1, Exception arg2) {}
			@Override
			public void remoteDeviceDiscoveryStarted(Registry arg0, RemoteDevice arg1) {}
			@Override
			public void afterShutdown() {}
			@Override
			public void beforeShutdown(Registry arg0) {}
			@Override
			public void localDeviceAdded(Registry arg0, LocalDevice arg1) {}
			@Override
			public void localDeviceRemoved(Registry arg0, LocalDevice arg1) {}
			@Override
			public void remoteDeviceRemoved(Registry arg0, RemoteDevice arg1) {}
			@Override
			public void remoteDeviceUpdated(Registry arg0, RemoteDevice arg1) {}
		});

		// Search for All Devices
		gUPnPService.getControlPoint().search(new STAllHeader());
	}

	/*****************************
	 * Utility Functions
	 *****************************/
	// Print retrunHash sorted by Value
	public static void printSortedHash(
			Vector<HashMap<String, String>> returnList) {

		System.out.println("  + UPnP Content:");
		for (int i = 0; i < returnList.size(); i++) {
			if (isFolder(returnList.elementAt(i))) {
				System.out.println("    / ("
						+ returnList.elementAt(i).get("Path") + "::" + returnList.elementAt(i).get("Title") + ")");
			} else {
				System.out.println("    - ("
						+ returnList.elementAt(i).get("Path") + "::" + returnList.elementAt(i).get("UIDTitle")  + ")");
			}
		}
	}
	// Check if hash entry is a Content folder
	public static String getMetadata(HashMap<String, String> item, String Metadata) {
		if (item != null){
			return item.get(Metadata);
		}
		return "";
	}

	public static String getDuration(HashMap<String, String> item) {
		if (item != null){
			String DurRegEx = "([0-9]+):([0-9]+):([0-9]+)\\.";
			Pattern pattern = Pattern.compile(DurRegEx);
			Matcher matcher = pattern.matcher(item.get("Duration"));
			if (matcher.find()){
				int hours = Integer.parseInt(matcher.group(1)) * 60;
				int minutes = Integer.parseInt(matcher.group(2)) * 60;
				return (hours + minutes) + " mins";
			}
		}
		return "";
	}
	
	public static int getDurationPlayback(HashMap<String, String> item) {
		if (item != null){
			String DurRegEx = "([0-9]+):([0-9]+):([0-9]+)\\.";
			Pattern pattern = Pattern.compile(DurRegEx);
			Matcher matcher = pattern.matcher(item.get("Duration"));
			if (matcher.find()){
				int hours = Integer.parseInt(matcher.group(1)) * 60 * 60;
				int minutes = Integer.parseInt(matcher.group(2)) * 60;
				int seconds = Integer.parseInt(matcher.group(3));
				return (hours + minutes + seconds) * 1000;
			}
		}
		return 0;
	}
	
	public static String getDate(HashMap<String, String> item) {
		if (item != null){
			String DateRegEx = "([0-9]+)-([0-9]+)-([0-9]+)";
			Pattern pattern = Pattern.compile(DateRegEx);
			Matcher matcher = pattern.matcher(item.get("date"));
			if (matcher.find()){
				return matcher.group(2) + "/" + matcher.group(3) + "/" + matcher.group(1); 
			}
		}
		return "";
	}
	
	public static String getDirectory(HashMap<String, String> item) {
		if (item != null){
			return item.get("Directory");
		}
		return "";
	}
	
	// Check if hash entry is a Content folder
	public static String getMedia(HashMap<String, String> item) {		
		if (item != null){
			return item.get("Media");
		}
		return "";
	}
	
	// Check if hash entry is a Content folder
	public static String getParentUID(HashMap<String, String> item) {
		if (item != null){
			return item.get("ParentUID");
		}
		return "";
	}
	
	// Check if hash entry is a Content folder
	public static String getPath(HashMap<String, String> item) {
		if (item != null){
			return item.get("Path");
		}
		return "";
	}
	
	// Check if hash entry is a Content folder
	public static String getAlbumArt(HashMap<String, String> item) {
		if (item != null){
			return item.get("AlbumArt");
		}
		return "";
	}

	// Check if hash entry is a Content folder
	public static String getUPnPDevice(HashMap<String, String> item) {
		if (item != null){
			return item.get("UPnPDevice");
		}
		return "";
	}
	
	// Check if hash entry is a Content folder
	public static boolean isFolder(HashMap<String, String> item) {
		if (item != null){
			return item.containsKey("Directory");
		}
		return false;
	}

	// Check if hash entry is a Media item
	public static boolean isMedia(HashMap<String, String> item) {
		if (item != null){
			return item.containsKey("Media");
		}
		return false;
	}

}
