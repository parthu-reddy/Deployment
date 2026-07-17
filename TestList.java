import java.util.*;
public class TestList {
    public static void main(String[] args) {
        List<String> rolesList = Arrays.asList("DELIVERY");
        String roles = (rolesList != null) ? String.join(",", rolesList) : "";
        System.out.println("roles=" + roles);
        
        List<String> rolesList2 = new ArrayList<>();
        rolesList2.add("DELIVERY");
        String roles2 = (rolesList2 != null) ? String.join(",", rolesList2) : "";
        System.out.println("roles2=" + roles2);
        
        System.out.println("rolesList.toString()=" + rolesList.toString());
    }
}
