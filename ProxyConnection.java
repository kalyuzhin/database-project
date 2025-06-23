import java.sql.*; 
import java.time.Instant; 
 
public class ProxyConnection { 
    private static final String PROXY_URL = "jdbc:postgresql://localhost:5433/games"; 
    private static final String USER = "postgres"; 
    private static final String PASSWORD = "postgres"; 
 
    public static void main(String[] args) { 
        try (Connection conn = DriverManager.getConnection(PROXY_URL, USER, PASSWORD)) { 
            testGames(conn);
            testComlicatedQuery(conn);
        } catch (SQLException e) { 
            e.printStackTrace(); 
        } 
    } 

    private static void testGames(Connection conn) throws SQLException {
        System.out.println("\n=== Тестируем игры ===");
        ResultSet res = executeQuery(conn, 
        "SELECT * FROM games;");
        printResultSet(res);

        executeUpdate(conn, 
            "INSERT INTO games (name, description, created_at, updated_at, author_id) VALUES " + 
            "('New test Game', 'Description of new test game', NOW(), NOW(), 1);");

        res = executeQuery(conn,
        "SELECT * FROM GAMES;");
        printResultSet(res);
    }

    private static void testComlicatedQuery(Connection conn) throws SQLException {
        System.out.println("\n=== Тестируем сложные запросы ===");
        ResultSet res = executeQuery(conn, 
        "SELECT g.name, r.user_mark FROM games g JOIN reviews r ON r.game_id = g.id;");
        printResultSet(res);
    }

    private static void executeUpdate(Connection conn, String sql) throws SQLException { 
        System.out.println("Executing: " + sql); 
        try (Statement stmt = conn.createStatement()) { 
            stmt.executeUpdate(sql); 
        } 
    }

    private static ResultSet executeQuery(Connection conn, String sql) throws SQLException { 
        System.out.println("Querying: " + sql); 
        return conn.createStatement().executeQuery(sql); 
    } 
     
    private static void printResultSet(ResultSet rs) throws SQLException { 
        ResultSetMetaData meta = rs.getMetaData(); 
        int columns = meta.getColumnCount(); 
         
        for (int i = 1; i <= columns; i++) { 
            System.out.printf("%-20s", meta.getColumnName(i)); 
        } 
        System.out.println(); 
         
        while (rs.next()) { 
            for (int i = 1; i <= columns; i++) { 
                System.out.printf("%-20s", rs.getString(i)); 
            } 
            System.out.println(); 
        } 
    }
}