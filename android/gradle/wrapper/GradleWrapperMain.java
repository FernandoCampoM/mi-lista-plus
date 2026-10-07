import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

final class GradleWrapperMain {
  public static void main(String[] args) throws Exception {
    Path wrapperDir = Path.of(System.getProperty("wrapper.dir"));
    Properties properties = new Properties();
    try (InputStream input = Files.newInputStream(wrapperDir.resolve("gradle-wrapper.properties"))) {
      properties.load(input);
    }
    String distributionUrl = properties.getProperty("distributionUrl");
    if (distributionUrl == null || !distributionUrl.startsWith("https://")) {
      throw new IllegalStateException("distributionUrl HTTPS no configurada");
    }
    String versionKey = Integer.toHexString(distributionUrl.hashCode());
    Path install = Path.of(System.getProperty("user.home"), ".gradle", "wrapper", "dists", "mi-lista-plus", versionKey);
    Path marker = install.resolve(".installed");
    if (!Files.exists(marker)) {
      Files.createDirectories(install);
      Path zip = install.resolve("distribution.zip.part");
      try (InputStream input = URI.create(distributionUrl).toURL().openStream();
           OutputStream output = Files.newOutputStream(zip)) {
        input.transferTo(output);
      }
      unzip(zip, install);
      Files.deleteIfExists(zip);
      Files.createFile(marker);
    }
    Path launcher;
    try (var paths = Files.walk(install)) {
      launcher = paths
          .filter(path -> path.getFileName().toString().startsWith("gradle-launcher-") && path.toString().endsWith(".jar"))
          .findFirst()
          .orElseThrow(() -> new IllegalStateException("No se encontro gradle-launcher"));
    }
    List<String> command = new ArrayList<>();
    command.add(Path.of(System.getProperty("java.home"), "bin", "java").toString());
    command.add("-classpath");
    command.add(launcher.toString());
    command.add("org.gradle.launcher.GradleMain");
    command.addAll(List.of(args));
    System.exit(new ProcessBuilder(command).inheritIO().start().waitFor());
  }

  private static void unzip(Path zip, Path target) throws Exception {
    try (ZipInputStream input = new ZipInputStream(Files.newInputStream(zip))) {
      ZipEntry entry;
      while ((entry = input.getNextEntry()) != null) {
        Path destination = target.resolve(entry.getName()).normalize();
        if (!destination.startsWith(target)) throw new IllegalStateException("Entrada ZIP invalida");
        if (entry.isDirectory()) {
          Files.createDirectories(destination);
        } else {
          Files.createDirectories(destination.getParent());
          Files.copy(input, destination, StandardCopyOption.REPLACE_EXISTING);
        }
      }
    }
  }
}
