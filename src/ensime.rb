#!/usr/bin/env ruby
require 'fileutils'
class Ensime
    def initialize conf_path
        @conf_path = conf_path
        @conf = Hash[File.read(conf_path).gsub("\n", "").gsub(
            "(", " ").gsub(")", " ").gsub('"', "").split(" :").collect do |x|
            m = x.match("\([^ ]*\) *\(.*\)$")
            [m[1], m[2]]
            end]
        @version = "0.9.10-SNAPSHOT"
    end
    def get_classpath
        log = nil 
        classpath = nil
        dir = "/tmp/classpath_project_ensime"
        classpath_file = "#{dir}/classpath"
        if not File.exists? classpath_file
        FileUtils.mkdir_p dir
        build_sbt = <<EOF
import sbt._
import IO._
import java.io._
scalaVersion := "#{@conf['scala-version']}"
ivyScala := ivyScala.value map { _.copy(overrideScalaVersion = true) }
// allows local builds of scala
resolvers += Resolver.mavenLocal
resolvers += Resolver.sonatypeRepo("snapshots")
resolvers += "Typesafe repository" at "http://repo.typesafe.com/typesafe/releases/"
resolvers += "Akka Repo" at "http://repo.akka.io/repository"
libraryDependencies ++= Seq(
  "org.ensime" %% "ensime" % "#{@version}",
  "org.scala-lang" % "scala-compiler" % scalaVersion.value force(),
  "org.scala-lang" % "scala-reflect" % scalaVersion.value force(),
  "org.scala-lang" % "scalap" % scalaVersion.value force()
)
val saveClasspathTask = TaskKey[Unit]("saveClasspath", "Save the classpath to a file")
saveClasspathTask := {
  val managed = (managedClasspath in Runtime).value.map(_.data.getAbsolutePath)
  val unmanaged = (unmanagedClasspath in Runtime).value.map(_.data.getAbsolutePath)
  val out = file("#{classpath_file}")
  write(out, (unmanaged ++ managed).mkString(File.pathSeparator))
}
EOF
            FileUtils.mkdir_p "#{dir}/project"
            File.write("#{dir}/build.sbt", build_sbt)
            File.write("#{dir}/project/build.properties", "sbt.version=0.13.8")
            Dir.chdir dir do 
                log = `sbt saveClasspath`
            end
            puts log
        end
        classpath = File.read classpath_file
        classpath + ":#{@conf['java-home']}/lib/tools.jar"
    end
    def run
        FileUtils.mkdir_p @conf['cache-dir']
        @pid = Process.spawn "#{@conf['java-home']}/bin/java #{@conf['java-flags']} \
        -cp #{get_classpath} -Densime.config=#{@conf_path} org.ensime.server.Server"
    end
    def stop
        Process.kill 'TERM', @pid if @pid
    end
end
Ensime.new(ARGV.size == 0 ? ".ensime" : ARGV[0]).run if __FILE__ == $0
