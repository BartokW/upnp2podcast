package PlayOnForSageTV;

public class PlayOnUtils 
{   
    public static boolean IsImportedNotPlayon(Object MediaObject) {
        return !IsPlayOnFile(MediaObject) && IsImportedTV(MediaObject);
    }

    public static boolean IsPlayOnFile(Object MediaObject) {
    	if (sagex.api.MediaFileAPI.GetMediaFileMetadata(MediaObject, "Copyright").contains("PlayOn")) {
        	return true;
    	}
    	return false;
    }

    public static String GetPlayonFilePath(Object MediaObject) {
    	String Comment = sagex.api.MediaFileAPI.GetMediaFileMetadata(MediaObject, "Comment");
    	String[] SplitString = Comment.split(",,,");
    	if (SplitString.length == 2)
    	{
    		return SplitString[1];    		
    	}
        return "";
    }
    
    public static String GetPlayonFileType(Object MediaObject) {
    	String Comment = sagex.api.MediaFileAPI.GetMediaFileMetadata(MediaObject, "Copyright");
    	String[] SplitString = Comment.split(",");
    	if (SplitString.length == 2)
    	{
    		return SplitString[1];    		
    	}
        return "";
    }
    
    public static String GetMediaType(Object MediaObject) {
        return sagex.api.MediaFileAPI.GetMediaFileMetadata(MediaObject, "MediaType");
    }

    public static boolean IsMediaTypeTV(Object MediaObject) {
        String Type = sagex.api.MediaFileAPI.GetMediaFileMetadata(MediaObject, "MediaType");
        if (Type.contains("TV") || sagex.api.MediaFileAPI.IsTVFile(MediaObject)) {
            return true;
        } else {

            return false;
        }
    }

    public static boolean IsImportedTV(Object MediaObject) {

        if (IsMediaTypeTV(MediaObject) && !sagex.api.MediaFileAPI.IsTVFile(MediaObject)) {
            return true;
        } else {
            return false;
        }
    }   
}
