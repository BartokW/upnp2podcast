package PlayOnForSageTV;

public class PlayOnUtils 
{
    public static String LegacyFileFormat = "MATROSKA[H.264 9:5 720x400@30fps]";
	public static String HuluFileFormat = "Quicktime[H.264/50Kbps 480x368@24fps]";
    public static String NetflixFileFormat = "Quicktime[H.264/50Kbps 480x368@25fps]";
    public static int HULU_TYPE = 1;
    public static int NETFLIX_TYPE = 2;
    public static int LEGACY_TYPE = 2;
    
    public static boolean IsPlayOnFile(Object MediaObject) 
    {
        String Type = sagex.api.MediaFileAPI.GetMediaFileFormatDescription(MediaObject);
        if (Type.equals(HuluFileFormat) || Type.equals(NetflixFileFormat) || Type.equals(LegacyFileFormat)) 
        {
            return true;
        }
        return false;
    }
    
    public static boolean IsPlayOnNetflixFile(Object MediaObject) 
    {
        String Type = sagex.api.MediaFileAPI.GetMediaFileFormatDescription(MediaObject);
        if (Type.equals(NetflixFileFormat)) 
        {
            return true;
        }
        return false;
    }

    public static boolean IsPlayOnHuluFile(Object MediaObject) 
    {
        String Type = sagex.api.MediaFileAPI.GetMediaFileFormatDescription(MediaObject);
        if (Type.equals(HuluFileFormat)) 
        {
            return true;
        }
        return false;
    }
    
    
    public static int GetPlayOnFileType(Object MediaObject) 
    {
        String Type = sagex.api.MediaFileAPI.GetMediaFileFormatDescription(MediaObject);
        if (Type.equals(HuluFileFormat)) 
        {
            return HULU_TYPE;
        }
        else if (Type.equals(NetflixFileFormat)) 
        {
            return NETFLIX_TYPE;
        } 
        else if (Type.equals(LegacyFileFormat)) 
        {
            return LEGACY_TYPE;
        }
        return 0;
    }
    
    
}
