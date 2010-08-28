/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package epplayon;

import sagex.plugin.IPropertyPersistence;

/**
 *
 * @author SBANTA
 */
public class EPButtonPersistance implements IPropertyPersistence  {


	@Override
	public void set(String string, String string1) {
          
	}

	@Override
	public String get(String string, String string1) {

          if(Boolean.parseBoolean(sagex.api.Configuration.GetServerProperty("PlayonPlayback/UpdateInProcess","false"))){
            return "Currently Updating";}
          else{
           return "Update Now";
          }
	}

}


