# frozen_string_literal: true

require 'spec_helper'

describe 'resource_artefacts::java' do
  context 'installs java' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'imports the java_se recipe' do
      expect(chef_run).to include_recipe('java')
    end
  end

  context 'disables caching of DNS results' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    java_security_content = <<~CONF
      #
      # This is the "master security properties file".

      #
      # List of providers and their preference orders (see above):
      #
      security.provider.1=sun.security.provider.Sun
      security.provider.2=sun.security.rsa.SunRsaSign
      security.provider.3=sun.security.ec.SunEC
      security.provider.4=com.sun.net.ssl.internal.ssl.Provider
      security.provider.5=com.sun.crypto.provider.SunJCE
      security.provider.6=sun.security.jgss.SunProvider
      security.provider.7=com.sun.security.sasl.Provider
      security.provider.8=org.jcp.xml.dsig.internal.dom.XMLDSigRI
      security.provider.9=sun.security.smartcardio.SunPCSC

      #
      # Sun Provider SecureRandom seed source.
      #
      securerandom.source=file:/dev/random

      #
      # A list of known strong SecureRandom implementations.
      #
      securerandom.strongAlgorithms=NativePRNGBlocking:SUN

      #
      # Class to instantiate as the javax.security.auth.login.Configuration
      # provider.
      #
      login.configuration.provider=sun.security.provider.ConfigFile

      #
      # Default login configuration file
      #
      #login.config.url.1=file:${user.home}/.java.login.config

      #
      # Class to instantiate as the system Policy. This is the name of the class
      # that will be used as the Policy object.
      #
      policy.provider=sun.security.provider.PolicyFile

      # The default is to have a single system-wide policy file,
      # and a policy file in the user's home directory.
      policy.url.1=file:${java.home}/lib/security/java.policy
      policy.url.2=file:${user.home}/.java.policy

      # whether or not we expand properties in the policy file
      # if this is set to false, properties (${...}) will not be expanded in policy
      # files.
      policy.expandProperties=true

      # whether or not we allow an extra policy to be passed on the command line
      # with -Djava.security.policy=somefile. Comment out this line to disable
      # this feature.
      policy.allowSystemProperty=true

      # whether or not we look into the IdentityScope for trusted Identities
      # when encountering a 1.1 signed JAR file. If the identity is found
      # and is trusted, we grant it AllPermission.
      policy.ignoreIdentityScope=false

      #
      # Default keystore type.
      #
      keystore.type=jks

      #
      # Controls compatibility mode for the JKS keystore type.
      #
      keystore.type.compat=true

      #
      # List of comma-separated packages that start with or equal this string
      # will cause a security exception to be thrown when
      # passed to checkPackageAccess unless the
      # corresponding RuntimePermission ("accessClassInPackage."+package) has
      # been granted.
      package.access=sun.,\
                    com.sun.xml.internal.,\
                    com.sun.imageio.,\
                    com.sun.istack.internal.,\
                    com.sun.jmx.,\
                    com.sun.media.sound.,\
                    com.sun.naming.internal.,\
                    com.sun.proxy.,\
                    com.sun.corba.se.,\
                    com.sun.org.apache.bcel.internal.,\
                    com.sun.org.apache.regexp.internal.,\
                    com.sun.org.apache.xerces.internal.,\
                    com.sun.org.apache.xpath.internal.,\
                    com.sun.org.apache.xalan.internal.extensions.,\
                    com.sun.org.apache.xalan.internal.lib.,\
                    com.sun.org.apache.xalan.internal.res.,\
                    com.sun.org.apache.xalan.internal.templates.,\
                    com.sun.org.apache.xalan.internal.utils.,\
                    com.sun.org.apache.xalan.internal.xslt.,\
                    com.sun.org.apache.xalan.internal.xsltc.cmdline.,\
                    com.sun.org.apache.xalan.internal.xsltc.compiler.,\
                    com.sun.org.apache.xalan.internal.xsltc.trax.,\
                    com.sun.org.apache.xalan.internal.xsltc.util.,\
                    com.sun.org.apache.xml.internal.res.,\
                    com.sun.org.apache.xml.internal.resolver.helpers.,\
                    com.sun.org.apache.xml.internal.resolver.readers.,\
                    com.sun.org.apache.xml.internal.security.,\
                    com.sun.org.apache.xml.internal.serializer.utils.,\
                    com.sun.org.apache.xml.internal.utils.,\
                    com.sun.org.glassfish.,\
                    com.oracle.xmlns.internal.,\
                    com.oracle.webservices.internal.,\
                    oracle.jrockit.jfr.,\
                    org.jcp.xml.dsig.internal.,\
                    jdk.internal.,\
                    jdk.nashorn.internal.,\
                    jdk.nashorn.tools.,\
                    jdk.xml.internal.,\
                    com.sun.activation.registries.

      #
      # List of comma-separated packages that start with or equal this string
      # will cause a security exception to be thrown when
      # passed to checkPackageDefinition unless the
      # corresponding RuntimePermission ("defineClassInPackage."+package) has
      # been granted.
      #
      package.definition=sun.,\
                    com.sun.xml.internal.,\
                    com.sun.imageio.,\
                    com.sun.istack.internal.,\
                    com.sun.jmx.,\
                    com.sun.media.sound.,\
                    com.sun.naming.internal.,\
                    com.sun.proxy.,\
                    com.sun.corba.se.,\
                    com.sun.org.apache.bcel.internal.,\
                    com.sun.org.apache.regexp.internal.,\
                    com.sun.org.apache.xerces.internal.,\
                    com.sun.org.apache.xpath.internal.,\
                    com.sun.org.apache.xalan.internal.extensions.,\
                    com.sun.org.apache.xalan.internal.lib.,\
                    com.sun.org.apache.xalan.internal.res.,\
                    com.sun.org.apache.xalan.internal.templates.,\
                    com.sun.org.apache.xalan.internal.utils.,\
                    com.sun.org.apache.xalan.internal.xslt.,\
                    com.sun.org.apache.xalan.internal.xsltc.cmdline.,\
                    com.sun.org.apache.xalan.internal.xsltc.compiler.,\
                    com.sun.org.apache.xalan.internal.xsltc.trax.,\
                    com.sun.org.apache.xalan.internal.xsltc.util.,\
                    com.sun.org.apache.xml.internal.res.,\
                    com.sun.org.apache.xml.internal.resolver.helpers.,\
                    com.sun.org.apache.xml.internal.resolver.readers.,\
                    com.sun.org.apache.xml.internal.security.,\
                    com.sun.org.apache.xml.internal.serializer.utils.,\
                    com.sun.org.apache.xml.internal.utils.,\
                    com.sun.org.glassfish.,\
                    com.oracle.xmlns.internal.,\
                    com.oracle.webservices.internal.,\
                    oracle.jrockit.jfr.,\
                    org.jcp.xml.dsig.internal.,\
                    jdk.internal.,\
                    jdk.nashorn.internal.,\
                    jdk.nashorn.tools.,\
                    jdk.xml.internal.,\
                    com.sun.activation.registries.

      #
      # Determines whether this properties file can be appended to
      # or overridden on the command line via -Djava.security.properties
      #
      security.overridePropertiesFile=true

      #
      # Determines the default key and trust manager factory algorithms for
      # the javax.net.ssl package.
      #
      ssl.KeyManagerFactory.algorithm=SunX509
      ssl.TrustManagerFactory.algorithm=PKIX

      #
      # The Java-level namelookup cache policy for successful lookups:
      #
      # any negative value: caching forever
      # any positive value: the number of seconds to cache an address for
      # zero: do not cache
      #
      # default value is forever (FOREVER). For security reasons, this
      # caching is made forever when a security manager is set. When a security
      # manager is not set, the default behavior in this implementation
      # is to cache for 30 seconds.
      #
      # NOTE: setting this to anything other than the default value can have
      #       serious security implications. Do not set it unless
      #       you are sure you are not exposed to DNS spoofing attack.
      #
      #networkaddress.cache.ttl=0

      # The Java-level namelookup cache policy for failed lookups:
      #
      # any negative value: cache forever
      # any positive value: the number of seconds to cache negative lookup results
      # zero: do not cache
      #
      # In some Microsoft Windows networking environments that employ
      # the WINS name service in addition to DNS, name service lookups
      # that fail may take a noticeably long time to return (approx. 5 seconds).
      # For this reason the default caching policy is to maintain these
      # results for 10 seconds.
      #
      networkaddress.cache.negative.ttl=0

      #
      # Properties to configure OCSP for certificate revocation checking
      #

      # Enable OCSP
      #
      # By default, OCSP is not used for certificate revocation checking.
      # This property enables the use of OCSP when set to the value "true".
      #
      #   ocsp.enable=true

      #
      # Location of the OCSP responder
      #
      #   ocsp.responderURL=http://ocsp.example.net:80

      #
      # Subject name of the OCSP responder's certificate
      #
      #   ocsp.responderCertSubjectName="CN=OCSP Responder, O=XYZ Corp"

      #
      # Issuer name of the OCSP responder's certificate
      #
      #   ocsp.responderCertIssuerName="CN=Enterprise CA, O=XYZ Corp"

      #
      # Serial number of the OCSP responder's certificate
      #
      #   ocsp.responderCertSerialNumber=2A:FF:00

      #
      # Policy for failed Kerberos KDC lookups:
      #
      krb5.kdc.bad.policy = tryLast

      # Algorithm restrictions for certification path (CertPath) processing
      #
      jdk.certpath.disabledAlgorithms=MD2, MD5, SHA1 jdkCA & usage TLSServer, \
          RSA keySize < 1024, DSA keySize < 1024, EC keySize < 224

      #
      # Algorithm restrictions for signed JAR files
      #
      jdk.jar.disabledAlgorithms=MD2, MD5, RSA keySize < 1024, DSA keySize < 1024

      #
      # Algorithm restrictions for Secure Socket Layer/Transport Layer Security
      # (SSL/TLS) processing
      #
      jdk.tls.disabledAlgorithms=SSLv3, RC4, DES, MD5withRSA, DH keySize < 1024, \
          EC keySize < 224, 3DES_EDE_CBC, anon, NULL

      # Legacy algorithms for Secure Socket Layer/Transport Layer Security (SSL/TLS)
      # processing in JSSE implementation.
      #
      jdk.tls.legacyAlgorithms= \
              K_NULL, C_NULL, M_NULL, \
              DH_anon, ECDH_anon, \
              RC4_128, RC4_40, DES_CBC, DES40_CBC, \
              3DES_EDE_CBC

      # Cryptographic Jurisdiction Policy defaults
      #
      crypto.policy=unlimited

      #
      # The policy for the XML Signature secure validation mode. The mode is
      # enabled by setting the property "org.jcp.xml.dsig.secureValidation" to
      # true with the javax.xml.crypto.XMLCryptoContext.setProperty() method,
      # or by running the code with a SecurityManager.
      #
      jdk.xml.dsig.secureValidationPolicy=\
          disallowAlg http://www.w3.org/TR/1999/REC-xslt-19991116,\
          disallowAlg http://www.w3.org/2001/04/xmldsig-more#rsa-md5,\
          disallowAlg http://www.w3.org/2001/04/xmldsig-more#hmac-md5,\
          disallowAlg http://www.w3.org/2001/04/xmldsig-more#md5,\
          maxTransforms 5,\
          maxReferences 30,\
          disallowReferenceUriSchemes file http https,\
          minKeySize RSA 1024,\
          minKeySize DSA 1024,\
          minKeySize EC 224,\
          noDuplicateIds,\
          noRetrievalMethodLoops

      #
      # Serialization process-wide filter
      #
      #jdk.serialFilter=pattern;pattern

      #
      # RMI Registry Serial Filter
      #
      #sun.rmi.registry.registryFilter=pattern;pattern

      #
      # JCEKS Encrypted Key Serial Filter
      #
      jceks.key.serialFilter = java.lang.Enum;java.security.KeyRep;\
        java.security.KeyRep$Type;javax.crypto.spec.SecretKeySpec;!*

      #
      # Policies for distrusting Certificate Authorities (CAs).
      #
      jdk.security.caDistrustPolicies=SYMANTEC_TLS
    CONF
    it 'updates the java.security file' do
      expect(chef_run).to create_file('/etc/java-8-openjdk/security/java.security')
        .with_content(java_security_content)
    end
  end
end
