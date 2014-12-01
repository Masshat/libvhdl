library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--+ including vhdl 2008 libraries
--+ These lines can be commented out when using
--+ a simulator with built-in VHDL 2008 support
library ieee_proposed;
  use ieee_proposed.standard_additions.all;
  use ieee_proposed.std_logic_1164_additions.all;
  use ieee_proposed.numeric_std_additions.all;

library osvvm;
  use osvvm.RandomPkg.all;

library libvhdl;
  use libvhdl.AssertP.all;
  use libvhdl.SimP.all;
  use libvhdl.QueueP.all;



entity WishBoneT is
end entity WishBoneT;



architecture sim of WishBoneT is


  component WishBoneMasterE is
    generic (
      G_ADR_WIDTH  : positive := 8;  --* address bus width
      G_DATA_WIDTH : positive := 8   --* data bus width
    );
    port (
      --+ wishbone system if
      WbRst_i       : in  std_logic;
      WbClk_i       : in  std_logic;
      --+ wishbone outputs
      WbCyc_o       : out std_logic;
      WbStb_o       : out std_logic;
      WbWe_o        : out std_logic;
      WbAdr_o       : out std_logic_vector(G_ADR_WIDTH-1 downto 0);
      WbDat_o       : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
      --+ wishbone inputs
      WbDat_i       : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
      WbAck_i       : in  std_logic;
      WbErr_i       : in  std_logic;
      --+ local register if
      LocalWen_i    : in  std_logic;
      LocalRen_i    : in  std_logic;
      LocalAdress_i : in  std_logic_vector(G_ADR_WIDTH-1 downto 0);
      LocalData_i   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
      LocalData_o   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
      LocalAck_o    : out std_logic;
      LocalError_o  : out std_logic
    );
  end component WishBoneMasterE;


  component WishBoneSlaveE is
    generic (
      G_ADR_WIDTH  : positive := 8;  --* address bus width
      G_DATA_WIDTH : positive := 8   --* data bus width
    );
    port (
      --+ wishbone system if
      WbRst_i       : in  std_logic;
      WbClk_i       : in  std_logic;
      --+ wishbone inputs
      WbCyc_i       : in  std_logic;
      WbStb_i       : in  std_logic;
      WbWe_i        : in  std_logic;
      WbAdr_i       : in  std_logic_vector(G_ADR_WIDTH-1 downto 0);
      WbDat_i       : in  std_logic_vector(G_DATA_WIDTH-1 downto 0);
      --* wishbone outputs
      WbDat_o       : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
      WbAck_o       : out std_logic;
      WbErr_o       : out std_logic;
      --+ local register if
      LocalWen_o    : out std_logic;
      LocalRen_o    : out std_logic;
      LocalAdress_o : out std_logic_vector(G_ADR_WIDTH-1 downto 0);
      LocalData_o   : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
      LocalData_i   : in  std_logic_vector(G_DATA_WIDTH-1 downto 0)
    );
  end component WishBoneSlaveE;


  --* testbench global clock period
  constant C_PERIOD     : time := 5 ns;
  --* Wishbone data width
  constant C_DATA_WIDTH : natural := 8;
  --* Wishbone address width
  constant C_ADDRESS_WIDTH : natural := 8;

  --* testbench global clock
  signal s_wb_clk : std_logic := '1';
  --* testbench global reset
  signal s_wb_reset : std_logic := '1';

  --+ test done array with entry for each test
  signal s_test_done : boolean;


  signal s_wb_cyc              : std_logic;
  signal s_wb_stb              : std_logic;
  signal s_wb_we               : std_logic;
  signal s_wb_adr              : std_logic_vector(C_ADDRESS_WIDTH-1 downto 0);
  signal s_wb_master_data      : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal s_wb_slave_data       : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal s_wb_ack              : std_logic;
  signal s_wb_err              : std_logic;
  signal s_master_local_wen    : std_logic;
  signal s_master_local_ren    : std_logic;
  signal s_master_local_adress : std_logic_vector(C_ADDRESS_WIDTH-1 downto 0);
  signal s_master_local_din    : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal s_master_local_dout   : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal s_master_local_ack    : std_logic;
  signal s_master_local_error  : std_logic;
  signal s_slave_local_wen     : std_logic;
  signal s_slave_local_ren     : std_logic;
  signal s_slave_local_adress  : std_logic_vector(C_ADDRESS_WIDTH-1 downto 0);
  signal s_slave_local_dout    : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal s_slave_local_din     : std_logic_vector(C_DATA_WIDTH-1 downto 0);

  type t_register is array (0 to integer'(2**C_ADDRESS_WIDTH-1)) of std_logic_vector(C_DATA_WIDTH-1 downto 0);

  shared variable sv_wishbone_queue : t_list_queue;


begin


  --* testbench global clock
  s_wb_clk <= not(s_wb_clk) after C_PERIOD/2 when not(s_test_done) else '0';
  --* testbench global reset
  s_wb_reset <= '0' after C_PERIOD * 5;


  WbMasterLocalP : process is
    variable v_random : RandomPType;
    variable v_wbmaster_data : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  begin
    v_random.InitSeed(v_random'instance_name);
    v_wbmaster_data       := (others => '0');
    s_master_local_din    <= (others => '0');
    s_master_local_adress <= (others => '0');
    s_master_local_wen    <= '0';
    s_master_local_ren    <= '0';
    wait until s_wb_reset = '0';
    -- write the wishbone slave registers
    for i in 0 to integer'(2**C_ADDRESS_WIDTH-1) loop
      v_wbmaster_data       := v_random.RandSlv(C_DATA_WIDTH);
      s_master_local_din    <= v_wbmaster_data;
      s_master_local_adress <= std_logic_vector(to_unsigned(i, C_ADDRESS_WIDTH));
      s_master_local_wen    <= '1';
      wait until rising_edge(s_wb_clk);
      s_master_local_din    <= (others => '0');
      s_master_local_adress <= (others => '0');
      s_master_local_wen    <= '0';
      wait until rising_edge(s_wb_clk) and s_master_local_ack = '1';
      sv_wishbone_queue.push(v_wbmaster_data);
    end loop;
    -- read back and check the wishbone slave registers
    for i in 0 to integer'(2**C_ADDRESS_WIDTH-1) loop
      s_master_local_adress <= std_logic_vector(to_unsigned(i, C_ADDRESS_WIDTH));
      s_master_local_ren    <= '1';
      wait until rising_edge(s_wb_clk);
      s_master_local_adress <= (others => '0');
      s_master_local_ren    <= '0';
      wait until rising_edge(s_wb_clk) and s_master_local_ack = '1';
      sv_wishbone_queue.pop(v_wbmaster_data);
      assert_equal(s_master_local_dout, v_wbmaster_data);
    end loop;
    report "INFO: Test successfully finished!";
    s_test_done <= true;
    wait;
  end process WbMasterLocalP;


  i_WishBoneMasterE : WishBoneMasterE
    generic map (
      G_ADR_WIDTH  => C_ADDRESS_WIDTH,
      G_DATA_WIDTH => C_DATA_WIDTH
    )
    port map (
      --+ wishbone system if
      WbRst_i       => s_wb_reset,
      WbClk_i       => s_wb_clk,
      --+ wishbone outputs
      WbCyc_o       => s_wb_cyc,
      WbStb_o       => s_wb_stb,
      WbWe_o        => s_wb_we,
      WbAdr_o       => s_wb_adr,
      WbDat_o       => s_wb_master_data,
      --+ wishbone inputs
      WbDat_i       => s_wb_slave_data,
      WbAck_i       => s_wb_ack,
      WbErr_i       => s_wb_err,
      --+ local register if
      LocalWen_i    => s_master_local_wen,
      LocalRen_i    => s_master_local_ren,
      LocalAdress_i => s_master_local_adress,
      LocalData_i   => s_master_local_din,
      LocalData_o   => s_master_local_dout,
      LocalAck_o    => s_master_local_ack,
      LocalError_o  => s_master_local_error
    );


   i_WishBoneSlaveE : WishBoneSlaveE
    generic map (
      G_ADR_WIDTH  => C_ADDRESS_WIDTH,
      G_DATA_WIDTH => C_DATA_WIDTH
    )
    port map (
      --+ wishbone system if
      WbRst_i       => s_wb_reset,
      WbClk_i       => s_wb_clk,
      --+ wishbone inputs
      WbCyc_i       => s_wb_cyc,
      WbStb_i       => s_wb_stb,
      WbWe_i        => s_wb_we,
      WbAdr_i       => s_wb_adr,
      WbDat_i       => s_wb_master_data,
      --* wishbone outputs
      WbDat_o       => s_wb_slave_data,
      WbAck_o       => s_wb_ack,
      WbErr_o       => s_wb_err,
      --+ local register if
      LocalWen_o    => s_slave_local_wen,
      LocalRen_o    => s_slave_local_ren,
      LocalAdress_o => s_slave_local_adress,
      LocalData_o   => s_slave_local_dout,
      LocalData_i   => s_slave_local_din
    );


    WbSlaveLocalP : process (s_wb_clk) is
      variable v_register : t_register := (others => (others => '0'));
    begin
      if (rising_edge(s_wb_clk)) then
        if (s_wb_reset = '1') then
          v_register        := (others => (others => '0'));
          s_slave_local_din <= (others => '0');
        else
          if (s_slave_local_wen = '1') then
            v_register(to_integer(unsigned(s_slave_local_adress))) := s_slave_local_dout;
          elsif (s_slave_local_ren = '1') then
            s_slave_local_din <= v_register(to_integer(unsigned(s_slave_local_adress)));
          end if;
        end if;
      end if;
    end process WbSlaveLocalP;


end architecture sim;