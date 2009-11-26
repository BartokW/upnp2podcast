import re
import os
import urllib2

string = "?>tryMe&&(>tryMe||(>!tryMe&&!tryMe<)<)<:>?>try1&&try2||!try3&&!(>try4||try5<):|try6<:>RESULT1<=>tryMe3<:>RESULT3<=>RESULT4<?<=>tryMe<:>RESULT<?"
perRunOptionsHash = {"try1":1, "try2":1, "try3":1}


def compareStringLength(a, b):
    return cmp(len(a), len(b)) # compare as integers
    
def findShortest(string,pattern,payLoadPattern):
    regex = re.compile("(?=(%s))" % pattern)
    matches = sorted(regex.findall(string),compareStringLength)
    if (len(matches)):
        return re.match(payLoadPattern,matches[0]).group("payLoad") # return shortest match
    else:
        return 0

def checkProfileCond(check,negate):
    condTrue = 0;  
    if (  (check != 0 and negate == 0) or (check == 0 and negate == 1)):
        condTrue = 1;
        print "                + " + ("!False (True)" if (negate == 1) else "True")
    else:
        print "                + " + ("!True (False)" if (negate == 1) else "False")
    return condTrue;
        
def checkConditional(check,perRunOptionsHash):
    negate = 0
    print "             - Checking: %s" % check
    
    if (re.match("^!",check)):
        negate = 1
        check = re.sub("^!",'',check)
        print "               + Negating: %s" % check
    
    if (check == "1" or check == "0"):
        print "               + Previously Resolved Condition: %s" % check  
        condTrue = checkProfileCond(check, negate);
    elif (re.match("EXISTS:(?P<PATH>.*)",check)):
        path = re.match("EXISTS:(?P<PATH>.*)",check).group("PATH")
        print "               + Does file (%s)" % (path)
        condTrue = checkProfileCond(os.path.exists(path), negate)     
    else: # Else, check for custom conditional 
        print "               + Does custom conditional (%s) exist? (%s)" % (check, (perRunOptionsHash[check.lower()] if perRunOptionsHash.has_key(check.lower()) else ""))
        condTrue = checkProfileCond(perRunOptionsHash.has_key(check.lower()), negate)                            
    return condTrue
    
def parseConditional(string,perRunOptionsHash):
    replaceString = ""
    while findShortest(string,"\?>.*?<\?","\?>(?P<payLoad>.*)<\?"):
        shortest = findShortest(string,"\?>.*?<\?","\?>(?P<payLoad>.*)<\?")
        condList = shortest.split("<=>")
        print "  + Shortest : "   + shortest
        print "  + Cond List: %s" % condList
        
        for cond in condList:
            print "     - cond : %s" % cond
            if (len(cond.split("<:>")) > 1):
                splitArray       = cond.split("<:>")
                conditionals     = "(>" + splitArray[0] + "<)"
                result           = splitArray[1]
                print "       + splitArray    : %s" % splitArray  
                print "       + conditionals  : " + conditionals
                print "       + Result        : " + result
                
                while findShortest(conditionals,"\\(>.*?<\\)","\\(>(?P<payLoad>.*)<\\)"):
                    shortestCondGroup = findShortest(conditionals,"\\(>.*?<\\)","\\(>(?P<payLoad>.*)<\\)")
                    print "         - Conditional List : " + shortestCondGroup
                    overall = 0  
                    toCheck   = []
                    checkWith = ["||"]
                    
                    toCheck   = re.split("[^a-zA-z0-9!]+",shortestCondGroup)
                    checkWith = re.split("[a-zA-z0-9!]+",shortestCondGroup)
                    checkWith.pop()
                    checkWith.reverse()
                    checkWith.pop()
                    checkWith.reverse()
                    checkWith.insert(0,"||")
                    checkWith.reverse()
                    
                    print "           + ToCheck   : %s" % toCheck
                    print "           + CheckWith : %s" % checkWith
                    
                    for check in toCheck:
                        result = checkConditional(check,perRunOptionsHash);
                        logicalOp = checkWith.pop();
                        if (logicalOp == "&&"):
                            if ((overall == 1) and (result == 1)):
                                overall = 1
                            else:
                                overall = 0        
                        elif(logicalOp == "!|"):
                            if ((result == 1) and (overall == 1)):
                                overall = 0
                            else:
                                overall = 1       
                        elif(logicalOp == "!&"):
                            if ((result == 0) and (overall == 0)):
                                overall = 1
                            else:
                                overall = 0    
                        elif(logicalOp == ":|"):
                            if (result == overall):
                                overall = 0
                            else:
                                overall = 1    
                        else: # ||
                            if (result == 1):
                                overall = 1
                            else:
                                overall = overall 
                      
                        print "           + Overall : %s" % overall   
                        
                    conditionals = re.sub(re.escape("(>" + shortestCondGroup + "<)"), "%s" % overall, conditionals)
                    
                if (overall == 1):
                    print "         - Overall: True, using: $%s" % (result)
                    replaceString = result
                    break
                    
            else:
                print "        = Overall: False, using else: %s" % cond
                replaceString = cond
                break
        if (replaceString == ""):
            print "        = Overall: False, leaving blank!"
            
        print "        = string        : %s" % string
        print "        = shortest      : %s" % shortest
        print "        = Replace String: %s" % replaceString
        string = re.sub(re.escape("?>" + shortest + "<?"), "%s" % replaceString, string)
        
    return string
    
print "!!! Result: %s" % parseConditional(string,perRunOptionsHash)





