package PlayOnForSageTV;

public class PlayOnUtils 
{
    public static String HuluFileFormat = "Quicktime[H.264/50Kbps 480x368@24fps]";
    public static String NetflixFileFormat = "Quicktime[H.264/50Kbps 480x368@25fps]";
    public static int HULU_TYPE = 1;
    public static int NETFLIX_TYPE = 2;
    
    public static boolean IsPlayOnFile(Object MediaObject) 
    {
        String Type = sagex.api.MediaFileAPI.GetMediaFileFormatDescription(MediaObject);
        if (Type.equals(HuluFileFormat) || Type.equals(NetflixFileFormat)) 
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
        if (Type.equals(NetflixFileFormat)) 
        {
            return NETFLIX_TYPE;
        } 
        return 0;
    }
    
    
}
