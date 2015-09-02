#!/usr/bin/env ruby
require 'fileutils'
require 'socket'
class Ensime
    attr_accessor :quiet
    def is_running?
        port_path = @conf_path + "_cache/http"
        return false if not File.exists? port_path
        begin
            TCPSocket.open("127.0.0.1", File.read(port_path).chomp).close
        rescue => e
            return false
        end
        true
    end
    def initialize conf_path
        @quiet = false
        @conf_path = conf_path
        @version = "0.9.10-SNAPSHOT"
        @conf = Hash[File.read(conf_path).gsub("\n", "").gsub(
            "(", " ").gsub(")", " ").gsub('"', "").split(" :").collect do |x|
            m = x.match("\([^ ]*\) *\(.*\)$")
            [m[1], m[2]]
            end] if File.exists? conf_path
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
        end
        classpath = File.read classpath_file
        classpath + ":#{@conf['java-home']}/lib/tools.jar"
    end
    def run
        if @conf.nil?
            puts "no #{@conf_path} file found" if not quiet
            return
        end
        if is_running?
            puts "ensime is already running"
        else
            FileUtils.mkdir_p @conf['cache-dir']
            out = quiet ? ".ensime_cache/server.log" : STDOUT
            @pid = Process.spawn(
                "#{@conf['java-home']}/bin/java #{@conf['java-flags']} \
        -cp #{get_classpath} -Densime.config=#{@conf_path} org.ensime.server.Server",
            :out => out)
        end
        self
    end
    def wait
        Process.wait @pid if @pid
    end
    def stop
        Process.kill 'TERM', @pid if @pid
    end
end
if __FILE__ == $0
    Ensime.new(ARGV.size == 0 ? ".ensime" : ARGV[0]).run.wait
end
