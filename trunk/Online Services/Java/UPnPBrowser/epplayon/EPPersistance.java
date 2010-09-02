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
public class EPPersistance implements IPropertyPersistence {

        

         @Override
         public void set(String property, String value) {
              sagex.api.Configuration.SetServerProperty(property,value);

              
                 }


         @Override
         public String get(String property, String defvalue) {

                         return sagex.api.Configuration.GetServerProperty(property, defvalue);
                        
                 }


 }



