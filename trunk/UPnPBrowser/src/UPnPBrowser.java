package playOnUtils;

import java.util.*;
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
	public static void main(String[] args) throws Exception {
		// Retrun Object
		HashMap<String, HashMap<String, String>> returnHash = null;
		String UID = "";
		String StaticPath = "";
		String UPnPDeviceRegEx = "playon";
		
		// Test #1: Get list of all UPnP Devices
		returnHash = new HashMap<String, HashMap<String, String>>();
		int SearchTime = 5;
		getUPnPDeviceList(returnHash,SearchTime);
		System.out.println("  + Found UPnP Servers");
		for (String device:returnHash.keySet()){
			System.out.println("    - (" + device + ")");
			
			// Set Device for next test
			if (device.contains("PlayOn")){
				UPnPDeviceRegEx = java.util.regex.Pattern.quote(device);
			}				
		}
		
		// Test #2: Get all items at a given path w/o initial UID	
		String Path = "Netflix::Instant Queue::Queue Top 50";
		int Depth = 1;
		getUPnPDirectoryForPath(returnHash, UPnPDeviceRegEx, Path, Depth);
		printSortedHash(returnHash);

		// Grab a UID and Static path for test #2
		for (String key : returnHash.keySet()) {
			if (isFolder(returnHash.get(key))) {
				UID = returnHash.get(key).get("Directory");
				StaticPath = returnHash.get(key).get("Path") + "::" + key;
			}
		}
		
		 // Test #3: Get all items at a given path WITH initial UID 
		 returnHash = new HashMap<String,HashMap<String,String>>(); Depth = 2;
		 getUPnPDirectoryForUID(returnHash, UPnPDeviceRegEx, UID, StaticPath, Depth);
		 printSortedHash(returnHash);
		 
	}

	/*****************************
	 * Public Functions
	 *****************************/
	// Start at root, navigate to path, store results in supplied hash
	public static void getUPnPDirectoryForPath(
			HashMap<String, HashMap<String, String>> returnHash,
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
		if (setUPnPDevice(UPnPDeviceRegEx)) {
			while (!UPnPPath.isEmpty() && CurrentUID != "") {
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
			getContentForUID(returnHash, CurrentUID, Path, Depth);
		} else {
			System.out.println("! Couldn't Find UPnP Device (" + UPnPDeviceRegEx + ")");
		}

		gUPnPService.shutdown();
		System.out.println("UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
		return;
	}

	// Get the UPnP Directory for a given UID and Server RegEx
	public static void getUPnPDirectoryForUID(
			HashMap<String, HashMap<String, String>> returnHash,
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
		if (setUPnPDevice(UPnPDeviceRegEx)) {
			getContentForUID(returnHash, UID, Path, Depth);
		} else {
			System.out.println("! Couldn't Find UPnP Device (" + UPnPDeviceRegEx + ")");
		}

		gUPnPService.shutdown();
		System.out.println("UPnPBrowser Finished! (" + (System.currentTimeMillis() - start) + " milliseconds)");
		return;
	}

	// Get the UPnP Directory for a given UID and Server RegEx
	public static void getUPnPDeviceList(
			HashMap<String, HashMap<String, String>> returnHash,
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
			returnHash.put(deviceName, KeyValue);			
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
			HashMap<String, HashMap<String, String>> returnHash, String UID,
			String Path, int Depth) {
		System.out.println("    - Getting Items from : (" + Path + ")(" + Depth + ")(" + UID + ")");
		getContentForUID(UID);
		List<Container> localContainers = gCurrentContainers;
		List<Item> localItems = gCurrentItems;

		for (Item item : localItems) {
			// Put in Path and ParentUID
			HashMap<String, String> KeyValue = new HashMap<String, String>();
			KeyValue.put("Path", Path);
			KeyValue.put("ParentUID", UID);
			KeyValue.put("UPnPDevice", gRemoteDeviceString);

			for (Res metaData : item.getResources()) {
				KeyValue.put("Media", metaData.getValue().toString());
				KeyValue.put("Duration", metaData.getDuration());
				KeyValue.put("Size", metaData.getSize().toString());
			}
			for (Property metaData : item.getProperties()) {
				KeyValue.put(metaData.getDescriptorName(), metaData.getValue()
						.toString());
			}
			returnHash.put(item.getTitle(), KeyValue);
		}

		// Folders
		for (Container container : localContainers) {
			if (Depth <= 1) {
				HashMap<String, String> KeyValue = new HashMap<String, String>();
				KeyValue.put("Path", Path);
				KeyValue.put("ParentUID", UID);
				KeyValue.put("Directory", container.getId());
				KeyValue.put("UPnPDevice", gRemoteDeviceString);
				returnHash.put(container.getTitle(), KeyValue);
			} else {
				getContentForUID(returnHash, container.getId(), Path + "::"
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
			public void remoteDeviceDiscoveryFailed(Registry arg0,
					RemoteDevice arg1, Exception arg2) {
			}

			@Override
			public void remoteDeviceDiscoveryStarted(Registry arg0,
					RemoteDevice arg1) {
			}

			@Override
			public void afterShutdown() {
			}

			@Override
			public void beforeShutdown(Registry arg0) {
			}

			@Override
			public void localDeviceAdded(Registry arg0, LocalDevice arg1) {
			}

			@Override
			public void localDeviceRemoved(Registry arg0, LocalDevice arg1) {
			}

			@Override
			public void remoteDeviceRemoved(Registry arg0, RemoteDevice arg1) {
			}

			@Override
			public void remoteDeviceUpdated(Registry arg0, RemoteDevice arg1) {
			}
		});

		// Search for All Devices
		gUPnPService.getControlPoint().search(new STAllHeader());
	}

	/*****************************
	 * Utility Functions
	 *****************************/
	// Print retrunHash sorted by Value
	public static void printSortedHash(
			HashMap<String, HashMap<String, String>> returnHash) {
		List<String> mapKeys = new ArrayList<String>(returnHash.keySet());
		List<String> mapValues = new ArrayList<String>();
		for (String key : mapKeys) {
			mapValues.add(returnHash.get(key).get("Path") + "::" + key);
		}

		TreeSet<String> sortedSet = new TreeSet<String>(mapValues);
		Object[] sortedArray = sortedSet.toArray();
		int size = sortedArray.length;

		System.out.println("  + UPnP Content:");
		for (int i = 0; i < size; i++) {
			String key = mapKeys.get(mapValues.indexOf(sortedArray[i]));
			if (isFolder(returnHash.get(key))) {
				System.out.println("    / ("
						+ returnHash.get(key).get("Path") + "::" + key + ")");
			} else {
				System.out.println("    - ("
						+ returnHash.get(key).get("Path") + "::" + key + ")");
			}
		}
	}

	// Check if hash entry is a Content folder
	public static boolean isFolder(HashMap<String, String> item) {
		return item.containsKey("Directory");
	}

	// Check if hash entry is a Media item
	public static boolean isMedia(HashMap<String, String> item) {
		return item.containsKey("Media");
	}

}
