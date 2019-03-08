# frozen_string_literal: true

#
# Cookbook Name:: resource_artefacts
# Recipe:: nexus_service
#
# Copyright 2018, P. van der Velde
#

#
# INSTALL THE CALCULATOR
#

apt_package 'bc' do
  action :install
end

#
# UPDATE THE SERVICE
#

# Make sure the nexus service doesn't start automatically. This will be changed
# after we have provisioned the box
service 'nexus' do
  action :disable
end

#
# SET THE JVM PARAMETERS
#

# Set the Jolokia jar as an agent so that we can export the JMX metrics to influx
# For the settings see here: https://jolokia.org/reference/html/agents.html#agents-jvm
jolokia_jar_path = node['jolokia']['path']['jar_file']
jolokia_agent_host = node['jolokia']['agent']['host']
jolokia_agent_port = node['jolokia']['agent']['port']
nexus_metrics_args =
  "-javaagent:#{jolokia_jar_path}=" \
  'protocol=http' \
  ",host=#{jolokia_agent_host}" \
  ",port=#{jolokia_agent_port}" \
  ',discoveryEnabled=false'

vmoptions_file = "#{node['nexus3']['install_path']}/bin/nexus.vmoptions"
file vmoptions_file do
  action :create
  content <<~PROPERTIES
    -XX:+UseConcMarkSweepGC
    -XX:+ExplicitGCInvokesConcurrent
    -XX:+ParallelRefProcEnabled
    -XX:+UseStringDeduplication
    -XX:+CMSParallelRemarkEnabled
    -XX:+CMSIncrementalMode
    -XX:CMSInitiatingOccupancyFraction=75
    -XX:+HeapDumpOnOutOfMemoryError
    -XX:+UnlockDiagnosticVMOptions
    -XX:+UnsyncloadClass
    -XX:+LogVMOutput
    -Djava.net.preferIPv4Stack=true
    -Dkaraf.home=.
    -Dkaraf.base=.
    -Dkaraf.etc=etc/karaf
    -Djava.util.logging.config.file=etc/karaf/java.util.logging.properties
    -Dkaraf.data=/home/nexus
    -Djava.io.tmpdir=/home/nexus/tmp
    -XX:LogFile=/home/nexus/log/jvm.log
    -Dkaraf.startLocalConsole=false
    #{nexus_metrics_args}
  PROPERTIES
end

#
# NEXUS START SCRIPT
#

# This was taken from the original Nexus install and adapted to be able to feed in the total memory
# of the machine so that we can set the maximum amount of memory for Nexus dynamically when the
# machine starts. Suggestions for how much memory to allocate are taken from here:
# https://help.sonatype.com/repomanager3/system-requirements#SystemRequirements-Memory
#
# General rules:
# - set minimum heap should always equal set maximum heap
# - minimum heap size 1200MB
# - maximum heap size <= 4GB
# - minimum MaxDirectMemory size 2GB
# - minimum unallocated physical memory should be no less than 1/3 of total physical RAM to allow for virtual memory swap
# - max heap + max direct memory <= host physical RAM * 2/3
#
# Suggested:
#
# small / personal
#   repositories < 20
#   total blobstore size < 20GB
#   single repository format type
# Memory: 4GB
#   -Xms1200M
#   -Xmx1200M
#   -XX:MaxDirectMemorySize=2G
#
# medium / team
#   repositories < 50
#   total blobstore size < 200GB
#    a few repository formats
# Memory: 8GB
#   -Xms2703M
#   -Xmx2703M
#   -XX:MaxDirectMemorySize=2703M
#
# 12GB
#   -Xms4G
#   -Xmx4G
#   -XX:MaxDirectMemorySize=4014M
#
# large / enterprise
#   repositories > 50
#   total blobstore size > 200GB
#   diverse set of repository formats
# Memory: 16GB
#   -Xms4G
#   -Xmx4G
#   -XX:MaxDirectMemorySize=6717M
#
#
# One issue is that the two minimums don't make 2/3 of 4Gb, so we assume that filling up the memory to 80% is acceptable.
# To calculate the memory usage if more than 4Gb of RAM is available we assume that we max out the
nexus_install_path = node['nexus3']['install_path']
nexus_start_file = "#{nexus_install_path}/bin/nexus"
file nexus_start_file do
  action :create
  content <<~SCRIPT
    #!/bin/sh
    # chkconfig:         2345 75 15
    # description:       nexus
    ### BEGIN INIT INFO
    # Provides:          nexus
    # Required-Start:    $all
    # Required-Stop:     $all
    # Default-Start:     2 3 4 5
    # Default-Stop:      0 1 6
    # Short-Description: nexus
    ### END INIT INFO

    # Uncomment the following line to override the JVM search sequence
    # INSTALL4J_JAVA_HOME_OVERRIDE=
    # Uncomment the following line to add additional VM parameters
    # INSTALL4J_ADD_VM_PARAMS=


    INSTALL4J_JAVA_PREFIX=""
    GREP_OPTIONS=""

    read_db_entry() {
      if [ -n "$INSTALL4J_NO_DB" ]; then
        return 1
      fi
      if [ ! -f "$db_file" ]; then
        return 1
      fi
      if [ ! -x "$java_exc" ]; then
        return 1
      fi
      found=1
      exec 7< $db_file
      while read r_type r_dir r_ver_major r_ver_minor r_ver_micro r_ver_patch r_ver_vendor<&7; do
        if [ "$r_type" = "JRE_VERSION" ]; then
          if [ "$r_dir" = "$test_dir" ]; then
            ver_major=$r_ver_major
            ver_minor=$r_ver_minor
            ver_micro=$r_ver_micro
            ver_patch=$r_ver_patch
          fi
        elif [ "$r_type" = "JRE_INFO" ]; then
          if [ "$r_dir" = "$test_dir" ]; then
            is_openjdk=$r_ver_major
            found=0
            break
          fi
        fi
      done
      exec 7<&-

      return $found
    }

    create_db_entry() {
      tested_jvm=true
      version_output=`"$bin_dir/java" $1 -version 2>&1`
      is_gcj=`expr "$version_output" : '.*gcj'`
      is_openjdk=`expr "$version_output" : '.*OpenJDK'`
      if [ "$is_gcj" = "0" ]; then
        java_version=`expr "$version_output" : '.*"\(.*\)".*'`
        ver_major=`expr "$java_version" : '\([0-9][0-9]*\)\..*'`
        ver_minor=`expr "$java_version" : '[0-9][0-9]*\.\([0-9][0-9]*\)\..*'`
        ver_micro=`expr "$java_version" : '[0-9][0-9]*\.[0-9][0-9]*\.\([0-9][0-9]*\).*'`
        ver_patch=`expr "$java_version" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*[\._]\([0-9][0-9]*\).*'`
      fi
      if [ "$ver_patch" = "" ]; then
        ver_patch=0
      fi
      if [ -n "$INSTALL4J_NO_DB" ]; then
        return
      fi
      db_new_file=${db_file}_new
      if [ -f "$db_file" ]; then
        awk '$1 != "'"$test_dir"'" {print $0}' $db_file > $db_new_file
        rm "$db_file"
        mv "$db_new_file" "$db_file"
      fi
      dir_escaped=`echo "$test_dir" | sed -e 's/ /\\\\ /g'`
      echo "JRE_VERSION     $dir_escaped    $ver_major      $ver_minor      $ver_micro      $ver_patch" >> $db_file
      echo "JRE_INFO        $dir_escaped    $is_openjdk" >> $db_file
      chmod g+w $db_file
    }

    test_jvm() {
      tested_jvm=na
      test_dir=$1
      bin_dir=$test_dir/bin
      java_exc=$bin_dir/java
      if [ -z "$test_dir" ] || [ ! -d "$bin_dir" ] || [ ! -f "$java_exc" ] || [ ! -x "$java_exc" ]; then
        return
      fi

      tested_jvm=false
      read_db_entry || create_db_entry $2

      if [ "$ver_major" = "" ]; then
        return;
      fi
      if [ "$ver_major" -lt "1" ]; then
        return;
      elif [ "$ver_major" -eq "1" ]; then
        if [ "$ver_minor" -lt "8" ]; then
          return;
        fi
      fi

      if [ "$ver_major" = "" ]; then
        return;
      fi
      if [ "$ver_major" -gt "1" ]; then
        return;
      elif [ "$ver_major" -eq "1" ]; then
        if [ "$ver_minor" -gt "8" ]; then
          return;
        fi
      fi

      app_java_home=$test_dir
    }

    add_class_path() {
      if [ -n "$1" ] && [ `expr "$1" : '.*\*'` -eq "0" ]; then
        local_classpath="$local_classpath${local_classpath:+:}$1"
      fi
    }

    compiz_workaround() {
      if [ "$is_openjdk" != "0" ]; then
        return;
      fi
      if [ "$ver_major" = "" ]; then
        return;
      fi
      if [ "$ver_major" -gt "1" ]; then
        return;
      elif [ "$ver_major" -eq "1" ]; then
        if [ "$ver_minor" -gt "6" ]; then
          return;
        elif [ "$ver_minor" -eq "6" ]; then
          if [ "$ver_micro" -gt "0" ]; then
            return;
          elif [ "$ver_micro" -eq "0" ]; then
            if [ "$ver_patch" -gt "09" ]; then
              return;
            fi
          fi
        fi
      fi


      osname=`uname -s`
      if [ "$osname" = "Linux" ]; then
        compiz=`ps -ef | grep -v grep | grep compiz`
        if [ -n "$compiz" ]; then
          export AWT_TOOLKIT=MToolkit
        fi
      fi

    }


    read_vmoptions() {
      vmoptions_file=`eval echo "$1" 2>/dev/null`
      if [ ! -r "$vmoptions_file" ]; then
        vmoptions_file="$prg_dir/$vmoptions_file"
      fi
      if [ -r "$vmoptions_file" ] && [ -f "$vmoptions_file" ]; then
        exec 8< "$vmoptions_file"
        while read cur_option<&8; do
            is_comment=`expr "W$cur_option" : 'W *#.*'`
          if [ "$is_comment" = "0" ]; then
            vmo_classpath=`expr "W$cur_option" : 'W *-classpath \(.*\)'`
            vmo_classpath_a=`expr "W$cur_option" : 'W *-classpath/a \(.*\)'`
            vmo_classpath_p=`expr "W$cur_option" : 'W *-classpath/p \(.*\)'`
            vmo_include=`expr "W$cur_option" : 'W *-include-options \(.*\)'`
            if [ ! "W$vmo_include" = "W" ]; then
                if [ "W$vmo_include_1" = "W" ]; then
                  vmo_include_1="$vmo_include"
                elif [ "W$vmo_include_2" = "W" ]; then
                  vmo_include_2="$vmo_include"
                elif [ "W$vmo_include_3" = "W" ]; then
                  vmo_include_3="$vmo_include"
                fi
            fi
            if [ ! "$vmo_classpath" = "" ]; then
              local_classpath="$i4j_classpath:$vmo_classpath"
            elif [ ! "$vmo_classpath_a" = "" ]; then
              local_classpath="${local_classpath}:${vmo_classpath_a}"
            elif [ ! "$vmo_classpath_p" = "" ]; then
              local_classpath="${vmo_classpath_p}:${local_classpath}"
            elif [ "W$vmo_include" = "W" ]; then
              needs_quotes=`expr "W$cur_option" : 'W.* .*'`
              if [ "$needs_quotes" = "0" ]; then
                vmoptions_val="$vmoptions_val $cur_option"
              else
                if [ "W$vmov_1" = "W" ]; then
                  vmov_1="$cur_option"
                elif [ "W$vmov_2" = "W" ]; then
                  vmov_2="$cur_option"
                elif [ "W$vmov_3" = "W" ]; then
                  vmov_3="$cur_option"
                elif [ "W$vmov_4" = "W" ]; then
                  vmov_4="$cur_option"
                elif [ "W$vmov_5" = "W" ]; then
                  vmov_5="$cur_option"
                fi
              fi
            fi
          fi
        done
        exec 8<&-
        if [ ! "W$vmo_include_1" = "W" ]; then
          vmo_include="$vmo_include_1"
          unset vmo_include_1
          read_vmoptions "$vmo_include"
        fi
        if [ ! "W$vmo_include_2" = "W" ]; then
          vmo_include="$vmo_include_2"
          unset vmo_include_2
          read_vmoptions "$vmo_include"
        fi
        if [ ! "W$vmo_include_3" = "W" ]; then
          vmo_include="$vmo_include_3"
          unset vmo_include_3
          read_vmoptions "$vmo_include"
        fi
      fi
    }


    unpack_file() {
      if [ -f "$1" ]; then
        jar_file=`echo "$1" | awk '{ print substr($0,1,length-5) }'`
        bin/unpack200 -r "$1" "$jar_file"

        if [ $? -ne 0 ]; then
          echo "Error unpacking jar files. The architecture or bitness (32/64)"
          echo "of the bundled JVM might not match your machine."
          echo "You might also need administrative privileges for this operation."
          exit 1
        fi
      fi
    }

    run_unpack200() {
      if [ -f "$1/lib/rt.jar.pack" ]; then
        old_pwd200=`pwd`
        cd "$1"
        echo "Preparing JRE ..."
        for pack_file in lib/*.jar.pack
        do
          unpack_file $pack_file
        done
        for pack_file in lib/ext/*.jar.pack
        do
          unpack_file $pack_file
        done
        cd "$old_pwd200"
      fi
    }

    search_jre() {
      if [ -z "$app_java_home" ]; then
        test_jvm $INSTALL4J_JAVA_HOME_OVERRIDE
      fi

      if [ -z "$app_java_home" ]; then
        if [ -f "$app_home/.install4j/pref_jre.cfg" ]; then
          read file_jvm_home < "$app_home/.install4j/pref_jre.cfg"
          test_jvm "$file_jvm_home"
          if [ -z "$app_java_home" ] && [ $tested_jvm = "false" ]; then
            if [ -f "$db_file" ]; then
              rm "$db_file" 2> /dev/null
            fi
            test_jvm "$file_jvm_home"
          fi
        fi
      fi

      if [ -z "$app_java_home" ]; then
        test_jvm "$app_home/jre"
        if [ -z "$app_java_home" ] && [ $tested_jvm = "false" ]; then
          if [ -f "$db_file" ]; then
            rm "$db_file" 2> /dev/null
          fi
          test_jvm "$app_home/jre"
        fi
      fi

      if [ -z "$app_java_home" ]; then
        prg_jvm=`which java 2> /dev/null`
        if [ ! -z "$prg_jvm" ] && [ -f "$prg_jvm" ]; then
          old_pwd_jvm=`pwd`
          path_java_bin=`dirname "$prg_jvm"`
          cd "$path_java_bin"
          prg_jvm=java

          while [ -h "$prg_jvm" ] ; do
            ls=`ls -ld "$prg_jvm"`
            link=`expr "$ls" : '.*-> \(.*\)$'`
            if expr "$link" : '.*/.*' > /dev/null; then
              prg_jvm="$link"
            else
              prg_jvm="`dirname $prg_jvm`/$link"
            fi
          done
          path_java_bin=`dirname "$prg_jvm"`
          cd "$path_java_bin"
          cd ..
          path_java_home=`pwd`
          cd "$old_pwd_jvm"
          test_jvm $path_java_home
        fi
      fi

      if [ -z "$app_java_home" ]; then
        common_jvm_locations="/opt/i4j_jres/* /usr/local/i4j_jres/* $HOME/.i4j_jres/* /usr/bin/java* /usr/bin/jdk* /usr/bin/jre* /usr/bin/j2*re* /usr/bin/j2sdk* /usr/java* /usr/java*/jre /usr/jdk* /usr/jre* /usr/j2*re* /usr/j2sdk* /usr/java/j2*re* /usr/java/j2sdk* /opt/java* /usr/java/jdk* /usr/java/jre* /usr/lib/java/jre /usr/local/java* /usr/local/jdk* /usr/local/jre* /usr/local/j2*re* /usr/local/j2sdk* /usr/jdk/java* /usr/jdk/jdk* /usr/jdk/jre* /usr/jdk/j2*re* /usr/jdk/j2sdk* /usr/lib/jvm/* /usr/lib/java* /usr/lib/jdk* /usr/lib/jre* /usr/lib/j2*re* /usr/lib/j2sdk* /System/Library/Frameworks/JavaVM.framework/Versions/1.?/Home /Library/Internet\ Plug-Ins/JavaAppletPlugin.plugin/Contents/Home /Library/Java/JavaVirtualMachines/*.jdk/Contents/Home/jre"
        for current_location in $common_jvm_locations
        do
          if [ -z "$app_java_home" ]; then
            test_jvm $current_location
          fi
        done
      fi

      if [ -z "$app_java_home" ]; then
        test_jvm $JAVA_HOME
      fi

      if [ -z "$app_java_home" ]; then
        test_jvm $JDK_HOME
      fi

      if [ -z "$app_java_home" ]; then
        test_jvm $INSTALL4J_JAVA_HOME
      fi

      if [ -z "$app_java_home" ]; then
        if [ -f "$app_home/.install4j/inst_jre.cfg" ]; then
          read file_jvm_home < "$app_home/.install4j/inst_jre.cfg"
          test_jvm "$file_jvm_home"
          if [ -z "$app_java_home" ] && [ $tested_jvm = "false" ]; then
            if [ -f "$db_file" ]; then
              rm "$db_file" 2> /dev/null
            fi
            test_jvm "$file_jvm_home"
          fi
        fi
      fi
    }

    max_memory() {
      max_mem=$(free -m | grep -oP '\\d+' | head -n 1)
      echo "${max_mem}"
    }

    java_memory() {
      java_max_memory=""

      max_mem="$(max_memory)"

      # Check for the 'real memory size' and calculate mx from a ratio given. Default is 80% so
      # that we can get the minimum requirements for the maximum memory and the maximum direct
      # memory as given here: https://help.sonatype.com/repomanager3/system-requirements#SystemRequirements-Memory
      ratio=80
      mx=$(echo "(${max_mem} * ${ratio} / 100 + 0.5)" | bc | awk '{printf("%d\\n",$1 + 0.5)}')

      # Define how much we are above 4Gb. If 4Gb or less return 0
      above_min=$(echo "n=(${max_mem} - 4096);if(n>0) n else 0" | bc | awk '{printf("%d\\n",$1 + 0.5)}')

      # Calculate how much memory we want to allocate
      max_java_mem=$(echo "(${above_min} / 8192) * 2800 + 1200" | bc -l | awk '{printf("%d\\n",$1 + 0.5)}')

      # Left over of the 80% goes to the direct memory
      max_java_direct_mem=$(echo "${mx} - ${max_java_mem}" | bc | awk '{printf("%d\\n",$1 + 0.5)}')

      echo "-Xmx${max_java_mem}m -Xms${max_java_mem}m -XX:MaxDirectMemorySize=${max_java_direct_mem}m"
    }

    old_pwd=`pwd`

    progname=`basename "$0"`
    linkdir=`dirname "$0"`

    cd "$linkdir"
    prg="$progname"

    while [ -h "$prg" ] ; do
      ls=`ls -ld "$prg"`
      link=`expr "$ls" : '.*-> \(.*\)$'`
      if expr "$link" : '.*/.*' > /dev/null; then
        prg="$link"
      else
        prg="`dirname $prg`/$link"
      fi
    done

    prg_dir=`dirname "$prg"`
    progname=`basename "$prg"`
    cd "$prg_dir"
    prg_dir=`pwd`
    app_home=../
    cd "$app_home"
    app_home=`pwd`
    bundled_jre_home="$app_home/jre"

    if [ "__i4j_lang_restart" = "$1" ]; then
      cd "$old_pwd"
    else
    cd "$prg_dir"/..

    fi
    if [ "__i4j_extract_and_exit" = "$1" ]; then
      cd "$old_pwd"
      exit 0
    fi
    db_home=$HOME
    db_file_suffix=
    if [ ! -w "$db_home" ]; then
      db_home=/tmp
      db_file_suffix=_$USER
    fi
    db_file=$db_home/.install4j$db_file_suffix
    if [ -d "$db_file" ] || ([ -f "$db_file" ] && [ ! -r "$db_file" ]) || ([ -f "$db_file" ] && [ ! -w "$db_file" ]); then
      db_file=$db_home/.install4j_jre$db_file_suffix
    fi
    if [ ! "__i4j_lang_restart" = "$1" ]; then
    run_unpack200 "$bundled_jre_home"
    run_unpack200 "$bundled_jre_home/jre"
    fi
    search_jre
    if [ -z "$app_java_home" ]; then
    if [ -f "$db_file" ]; then
      rm "$db_file" 2> /dev/null
    fi
      search_jre
    fi
    if [ -z "$app_java_home" ]; then
      echo No suitable Java Virtual Machine could be found on your system.
      echo The version of the JVM must be at least 1.8 and at most 1.8.
      echo Please define INSTALL4J_JAVA_HOME to point to a suitable JVM.
    exit 83
    fi

    compiz_workaround
    i4j_classpath="$app_home/.install4j/i4jruntime.jar"
    local_classpath=""
    add_class_path "$i4j_classpath"
    add_class_path "$app_home/lib/boot/nexus-main.jar"
    add_class_path "$app_home/lib/boot/org.apache.karaf.main-4.0.9.jar"
    add_class_path "$app_home/lib/boot/org.osgi.core-6.0.0.jar"
    add_class_path "$app_home/lib/boot/org.apache.karaf.diagnostic.boot-4.0.9.jar"
    add_class_path "$app_home/lib/boot/org.apache.karaf.jaas.boot-4.0.9.jar"

    java_mem="$(java_memory)"
    INSTALL4J_ADD_VM_PARAMS="$INSTALL4J_ADD_VM_PARAMS $java_mem"

    vmoptions_val=""
    read_vmoptions "$prg_dir/$progname.vmoptions"
    INSTALL4J_ADD_VM_PARAMS="$INSTALL4J_ADD_VM_PARAMS $vmoptions_val"


    LD_LIBRARY_PATH="$app_home/lib:$LD_LIBRARY_PATH"
    DYLD_LIBRARY_PATH="$app_home/lib:$DYLD_LIBRARY_PATH"
    SHLIB_PATH="$app_home/lib:$SHLIB_PATH"
    LIBPATH="$app_home/lib:$LIBPATH"
    LD_LIBRARYN32_PATH="$app_home/lib:$LD_LIBRARYN32_PATH"
    LD_LIBRARYN64_PATH="$app_home/lib:$LD_LIBRARYN64_PATH"
    export LD_LIBRARY_PATH
    export DYLD_LIBRARY_PATH
    export SHLIB_PATH
    export LIBPATH
    export LD_LIBRARYN32_PATH
    export LD_LIBRARYN64_PATH

    INSTALL4J_ADD_VM_PARAMS="$INSTALL4J_ADD_VM_PARAMS -Di4j.vpt=true"
    for param in $@; do
      if [ `echo "W$param" | cut -c -3` = "W-J" ]; then
        INSTALL4J_ADD_VM_PARAMS="$INSTALL4J_ADD_VM_PARAMS `echo "$param" | cut -c 3-`"
      fi
    done

    # user to execute as; optional but recommended to set
    run_as_user=''

    # load optional configuration
    rc_file="$prg_dir/${progname}.rc"
    if [ -f "$rc_file" ]; then
      . "$rc_file"
    fi

    # detect if execute as root user
    run_as_root=true
    user_id=`id -u`
    user_name=`id -u -n`
    if [ -z "$run_as_user" -a $user_id -ne 0 ]; then
      run_as_root=false
    elif [ -n "$run_as_user" -a "$run_as_user" != 'root' ]; then
      run_as_root=false
    fi

    # complain if root execution is detected
    if $run_as_root; then
      echo 'WARNING: ************************************************************'
      echo 'WARNING: Detected execution as "root" user.  This is NOT recommended!'
      echo 'WARNING: ************************************************************'
    elif [ -n "$run_as_user" -a "$run_as_user" != "$user_name" ]; then
      # re-execute launcher script as specified user
      exec su - $run_as_user "$prg_dir/$progname" $@
    fi

    # deduce the chosen data directory and prepare log and tmp directories
    vm_args="$vmov_1 $vmov_2 $vmov_3 $vmov_4 $vmov_5 $INSTALL4J_ADD_VM_PARAMS"
    if expr "$vm_args" : '.*-Dkaraf\.data=.*' > /dev/null; then
      data_dir=`echo "$vm_args -X" | sed -e 's/.*-Dkaraf\.data=//' -e 's/  *-[A-Za-z].*//'`
      mkdir -p "$data_dir/log" "$data_dir/tmp"
    fi

    if [ "W$vmov_1" = "W" ]; then
      vmov_1="-Di4jv=0"
    fi
    if [ "W$vmov_2" = "W" ]; then
      vmov_2="-Di4jv=0"
    fi
    if [ "W$vmov_3" = "W" ]; then
      vmov_3="-Di4jv=0"
    fi
    if [ "W$vmov_4" = "W" ]; then
      vmov_4="-Di4jv=0"
    fi
    if [ "W$vmov_5" = "W" ]; then
      vmov_5="-Di4jv=0"

    fi

    case "$1" in
        start)
            echo "Starting nexus"

    $INSTALL4J_JAVA_PREFIX nohup "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" "-XX:+UnlockDiagnosticVMOptions" "-Dinstall4j.launcherId=245" "-Dinstall4j.swt=false" "$vmov_1" "$vmov_2" "$vmov_3" "$vmov_4" "$vmov_5" $INSTALL4J_ADD_VM_PARAMS -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher start 9d17dc87 "" "" org.sonatype.nexus.karaf.NexusMain  > /dev/null 2>&1 &

        ;;
        start-launchd)
            echo "Starting nexus"

    $INSTALL4J_JAVA_PREFIX exec "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" "-XX:+UnlockDiagnosticVMOptions" "-Dinstall4j.launcherId=245" "-Dinstall4j.swt=false" "$vmov_1" "$vmov_2" "$vmov_3" "$vmov_4" "$vmov_5" $INSTALL4J_ADD_VM_PARAMS -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher start 9d17dc87 "" "" org.sonatype.nexus.karaf.NexusMain

        ;;
        stop)
            echo "Shutting down nexus"

    $INSTALL4J_JAVA_PREFIX exec "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher stop


        ;;
        restart|force-reload)
            echo "Shutting down nexus"

    $INSTALL4J_JAVA_PREFIX "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher stop


            echo "Restarting nexus"

    $INSTALL4J_JAVA_PREFIX nohup "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" "-XX:+UnlockDiagnosticVMOptions" "-Dinstall4j.launcherId=245" "-Dinstall4j.swt=false" "$vmov_1" "$vmov_2" "$vmov_3" "$vmov_4" "$vmov_5" $INSTALL4J_ADD_VM_PARAMS -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher start 9d17dc87 "" "" org.sonatype.nexus.karaf.NexusMain  > /dev/null 2>&1 &

        ;;
        status)

    $INSTALL4J_JAVA_PREFIX exec "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher status


        ;;
        run)

    $INSTALL4J_JAVA_PREFIX exec "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" "-XX:+UnlockDiagnosticVMOptions" "-Dinstall4j.launcherId=245" "-Dinstall4j.swt=false" "$vmov_1" "$vmov_2" "$vmov_3" "$vmov_4" "$vmov_5" $INSTALL4J_ADD_VM_PARAMS -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher run 9d17dc87 "" "" org.sonatype.nexus.karaf.NexusMain

        ;;
        run-redirect)

    $INSTALL4J_JAVA_PREFIX exec "$app_java_home/bin/java" -server -Dinstall4j.jvmDir="$app_java_home" -Dexe4j.moduleName="$prg_dir/$progname" "-XX:+UnlockDiagnosticVMOptions" "-Dinstall4j.launcherId=245" "-Dinstall4j.swt=false" "$vmov_1" "$vmov_2" "$vmov_3" "$vmov_4" "$vmov_5" $INSTALL4J_ADD_VM_PARAMS -classpath "$local_classpath" com.install4j.runtime.launcher.UnixLauncher run-redirect 9d17dc87 "" "" org.sonatype.nexus.karaf.NexusMain

        ;;
        *)
            echo "Usage: $0 {start|stop|run|run-redirect|status|restart|force-reload}"
            exit 1
        ;;
    esac

    exit $?
  SCRIPT
  group node['nexus3']['service_group']
  mode '0550'
  owner node['nexus3']['service_user']
end

# Update the systemd service configuration for Nexus so that we can set
# the number of file handles for the given user
# See here: https://help.sonatype.com/display/NXRM3/System+Requirements#filehandles
systemd_service 'nexus' do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start '/opt/nexus/bin/nexus start'
    exec_stop '/opt/nexus/bin/nexus stop'
    limit_nofile 65_536
    restart 'on-abort'
    type 'forking'
    user node['nexus3']['service_user']
  end
  unit do
    after %w[network.target]
    description 'nexus service'
  end
end

#
# SET THE PROXY PATH
#

nexus_data_path = node['nexus3']['data']
nexus_management_port = node['nexus3']['port']
nexus_proxy_path = node['nexus3']['proxy_path']
file "#{nexus_data_path}/etc/nexus.properties" do
  action :create
  content <<~PROPERTIES
    # Jetty section
    application-port=#{nexus_management_port}
    application-host=0.0.0.0
    nexus-args=${jetty.etc}/jetty.xml,${jetty.etc}/jetty-http.xml,${jetty.etc}/jetty-requestlog.xml
    nexus-context-path=#{nexus_proxy_path}
  PROPERTIES
end
