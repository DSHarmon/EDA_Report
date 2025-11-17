-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- 用于 unsigned 类型的算术运算

-- 实体定义
entity hc595_ctrl is
    port (
        sys_clk   : in  std_logic;                     -- 系统时钟，频率50MHz
        sys_rst_n : in  std_logic;                     -- 复位信号，低有效
        sel       : in  std_logic_vector(5 downto 0);  -- 数码管位选信号
        seg       : in  std_logic_vector(7 downto 0);  -- 数码管段选信号
        
        stcp      : out std_logic;                     -- 数据存储器时钟
        shcp      : out std_logic;                     -- 移位寄存器时钟
        ds        : out std_logic;                     -- 串行数据输入
        oe        : out std_logic                      -- 使能信号，低有效
    );
end entity hc595_ctrl;

-- 结构体定义
architecture Behavioral of hc595_ctrl is

    -- 内部信号声明
    signal cnt_4   : unsigned(1 downto 0);    -- 分频计数器 (0-3)
    signal cnt_bit : unsigned(3 downto 0);    -- 传输位数计数器 (0-13)
    -- 修正：将 data 信号类型改为 std_logic_vector，宽度为 14 位 (13 downto 0)
    signal data    : std_logic_vector(13 downto 0); -- 数码管信号寄存

begin

    -- =============================================================================
    -- 将数码管信号（段选 + 位选）拼接成一个14位的串行数据流
    -- 拼接操作的结果是 std_logic_vector 类型，与修正后的 data 信号类型匹配
    -- =============================================================================
    data <= seg(0) & seg(1) & seg(2) & seg(3) & seg(4) & seg(5) & seg(6) & seg(7) & sel;

    -- =============================================================================
    -- 使能信号 oe，低电平有效。复位时（sys_rst_n为低），oe为高，禁止输出。
    -- 复位释放后，oe为低，允许输出。
    -- =============================================================================
    oe <= not sys_rst_n;

    -- =============================================================================
    -- cnt_4: 0~3循环计数，用于产生分频时钟
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_4 <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_4 = to_unsigned(3, cnt_4'length) then
                cnt_4 <= (others => '0');
            else
                cnt_4 <= cnt_4 + 1;
            end if;
        end if;
    end process;

    -- =============================================================================
    -- cnt_bit: 每传输一位数据加1，计数到13（共14位）后清零
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_bit <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_4 = to_unsigned(3, cnt_4'length) then
                if cnt_bit = to_unsigned(13, cnt_bit'length) then
                    cnt_bit <= (others => '0');
                else
                    cnt_bit <= cnt_bit + 1;
                end if;
            end if;
        end if;
    end process;

    -- =============================================================================
    -- stcp: 存储寄存器时钟。在14位数据全部传输完毕后，产生一个上升沿，
    -- 将移位寄存器的数据锁存到存储寄存器。
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            stcp <= '0';
        elsif rising_edge(sys_clk) then
            if (cnt_bit = to_unsigned(13, cnt_bit'length)) and (cnt_4 = to_unsigned(3, cnt_4'length)) then
                stcp <= '1';
            else
                stcp <= '0';
            end if;
        end if;
    end process;

    -- =============================================================================
    -- shcp: 移位寄存器时钟。产生一个四分频的时钟（占空比50%）。
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            shcp <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_4 >= to_unsigned(2, cnt_4'length) then
                shcp <= '1';
            else
                shcp <= '0';
            end if;
        end if;
    end process;

    -- =============================================================================
    -- ds: 串行数据输出。在shcp的上升沿之前，准备好下一位要传输的数据。
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            ds <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_4 = to_unsigned(0, cnt_4'length) then
                -- data 现在是 std_logic_vector，可以直接用 to_integer(cnt_bit) 索引
                ds <= data(to_integer(cnt_bit));
            end if;
        end if;
    end process;

end architecture Behavioral;