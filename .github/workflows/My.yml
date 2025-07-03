# Copyright (c) 2022-2023 SMALLPROGRAM <https://github.com/smallprogram>
# Description: Auto compile
#
name: "Auto compile with openwrt sdk for luci-app-opengn2"
on:
  repository_dispatch:
  workflow_dispatch:
    inputs:
      ssh:
        description: 'SSH connection to Actions'
        required: false
        default: 'false'
env:
  TZ: Asia/Shanghai
  opengn2_repo: ${{ github.repository }}
  packages: peditx/Openwrt-OpenGN

jobs:
  job_check:
    name: Check Version
    runs-on: ubuntu-22.04
    outputs:
      opengn2_version: ${{ steps.check_version.outputs.latest_version }}
      has_update: ${{ steps.check_version.outputs.has_update }}
      prerelease: ${{ steps.check_version.outputs.prerelease }}
    steps:
      - name: Checkout
        uses: actions/checkout@main
        with:
          fetch-depth: 0
          ref: ${{ github.ref_name }}

      - name: Check version
        id: check_version
        env:
          url_tags: https://api.github.com/repos/${{ env.opengn2_repo }}/tags
        run: |
          cd luci-app-opengn2
          latest_version=$(awk -F ':=' '/PKG_VERSION|PKG_RELEASE/ {print $2}' Makefile | sed ':a;N;s/\$(PKG_VERSION)-//;s/\n$//;s/\n/-/;ba')
          has_update=$([ -z "$(wget -qO- -t1 -T2 ${{env.url_tags}} | grep \"${latest_version}\")" ] && echo true || echo false)
          prerelease=$([ "${{ github.ref_name }}" == "main" ] && echo false || echo true)
          echo "latest_version=${latest_version}" >> $GITHUB_OUTPUT
          echo "has_update=${has_update}" >> $GITHUB_OUTPUT
          echo "prerelease=${prerelease}" >> $GITHUB_OUTPUT
          echo "latest_version: ${latest_version}"
          echo "has_update: ${has_update}"
          echo "prerelease: ${prerelease}"

      - name: Prepare release
        if: steps.check_version.outputs.has_update == 'true'
        run: |
          echo "## :mega:Update content" >> release.txt
          echo "![](https://img.shields.io/github/downloads/${{ env.opengn2_repo }}/${{steps.check_version.outputs.latest_version}}/total?style=flat-square)" >> release.txt
          echo "### OpenGN2 Info" >> release.txt
          echo "**:minidisc: OpenGN2 Version: ${{steps.check_version.outputs.latest_version}}**" >> release.txt
          touch release.txt

      - name: Generate new tag & release
        if: steps.check_version.outputs.has_update == 'true'
        uses: softprops/action-gh-release@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{steps.check_version.outputs.latest_version}}
          target_commitish: ${{ github.ref_name }}
          prerelease: ${{steps.check_version.outputs.prerelease}}
          body_path: release.txt


  job_build_opengn2:
    name: Build luci-app-opengn2 [Luci ${{ matrix.luci_ver }}]
    needs: job_check
    if: needs.job_check.outputs.has_update == 'true'
    runs-on: ubuntu-22.04
    strategy:
      fail-fast: false
      matrix:
        include:
          - sdk_ver: "21.02"
            luci_ver: "19.07"
            sdk_url: https://downloads.openwrt.org/releases/21.02.7/targets/x86/64/openwrt-sdk-21.02.7-x86-64_gcc-8.4.0_musl.Linux-x86_64.tar.xz

          - sdk_ver: "24.10"
            luci_ver: "24.10"
            sdk_url: https://downloads.openwrt.org/releases/24.10.0/targets/x86/64/openwrt-sdk-24.10.0-x86-64_gcc-13.3.0_musl.Linux-x86_64.tar.zst
    steps:
      - name: Install packages
        run: |
          sudo -E rm -rf /usr/share/dotnet /etc/mysql /etc/php /etc/apt/sources.list.d /usr/local/lib/android
          echo "Install packages"
          sudo -E apt-get -qq update
          sudo -E apt-get -qq install build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev python3-distutils python3-setuptools rsync swig unzip zlib1g-dev file wget
          sudo -E apt-get -qq autoremove --purge
          sudo -E apt-get -qq clean

      - name: Cache openwrt SDK
        id: cache-sdk
        uses: actions/cache@v4
        with:
          path: sdk
          key: openwrt-luci-${{ matrix.luci_ver }}-x86_64

      - name: Initialization environment
        if: steps.cache-sdk.outputs.cache-hit != 'true'
        run: |
          wget ${{ matrix.sdk_url }}
          file_name=$(echo ${{ matrix.sdk_url }} | awk -F/ '{print $NF}')
          mkdir sdk && tar --zstd -x -f $file_name -C ./sdk --strip-components=1
          cd sdk
          echo "src-git base https://github.com/openwrt/openwrt.git;openwrt-${{ matrix.sdk_ver }}" > feeds.conf
          echo "src-git packages https://github.com/openwrt/packages.git;openwrt-${{ matrix.sdk_ver }}" >> feeds.conf
          echo "src-git luci https://github.com/openwrt/luci.git;openwrt-${{ matrix.luci_ver }}" >> feeds.conf
          echo "src-git routing https://git.openwrt.org/feed/routing.git;openwrt-${{ matrix.sdk_ver }}"  >> feeds.conf
          echo "src-git opengn2_packages https://github.com/${{ env.packages }}.git;main" >> feeds.conf
          echo "src-git opengn2 https://github.com/${{ env.opengn2_repo }}.git;${{ github.ref_name }}" >> feeds.conf

          rm -rf feeds/packages/lang/golang
          git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang

          ./scripts/feeds update -a
          echo "CONFIG_PACKAGE_luci-app-opengn2=m" > .config
          ./scripts/feeds install -d n luci-app-opengn2
          make package/luci-app-opengn2/download -j$(nproc)

      - name: Update opengn2 feeds
        if: steps.cache-sdk.outputs.cache-hit == 'true'
        run: |
          cd sdk
          sed -i '6s/main/${{ github.ref_name }}/' feeds.conf
          ./scripts/feeds update opengn2_packages
          ./scripts/feeds update opengn2
          ./scripts/feeds install luci-app-opengn2

      - name: Compile opengn2
        id: compile
        run: |
          cd sdk
          echo "CONFIG_ALL_NONSHARED=n" > .config
          echo "CONFIG_ALL_KMODS=n" >> .config
          echo "CONFIG_ALL=n" >> .config
          echo "CONFIG_AUTOREMOVE=n" >> .config
          echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config
          echo "CONFIG_PACKAGE_luci-app-opengn2=m" >> .config
          make defconfig
          echo "make package/luci-app-opengn2/{clean,compile} -j$(nproc)"
          make package/luci-app-opengn2/{clean,compile} -j$(nproc) V=s
          mv bin/packages/x86_64/opengn2/ ../
          make clean
          rm .config .config.old
          rm -rf feeds/opengn2 feeds/opengn2.*
          cd ../opengn2
          for i in $(ls); do mv $i luci-${{ matrix.luci_ver }}_$i; done
          cd ..
          echo "status=success" >> $GITHUB_OUTPUT
          echo "FIRMWARE=$PWD" >> $GITHUB_ENV

      - name: Upload opengn2 ipks to release
        uses: softprops/action-gh-release@v2
        if: steps.compile.outputs.status == 'success'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{needs.job_check.outputs.opengn2_version}}
          files: ${{ env.FIRMWARE }}/opengn2/*.ipk


  job_auto_compile:
